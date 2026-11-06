"""Stage and run an isolated low-priority P1k QA benchmark over pinned SSH.

Uses the configured deploy identity only for a separate /tmp directory. This
does not call the deployment helper, change services, or read account data.
"""
import argparse
from hashlib import sha256
import json
import os
from pathlib import Path
import shlex
import sys
import uuid

from export_true_fpp_p1k_qa import ROOT, benchmark_sources, file_hash, gameplay_hashes


REMOTE_PROGRAM = r'''
import json, math, os, platform, statistics, subprocess, time
from pathlib import Path

root = Path.cwd()
manifest = json.loads((root / "p1k_export.json").read_text())
parameters = {"samples": 600, "warmup": 120, "pace_usec": 16667}
host = {"platform": platform.platform(), "machine": platform.machine(),
        "cpu": next((line.split(":",1)[1].strip() for line in Path("/proc/cpuinfo").read_text().splitlines()
                     if line.startswith("model name")), "unknown")}

def trial(mode, pair, arm):
    folder = root / f"{mode}-{pair}-{arm}"
    folder.mkdir()
    pilot = mode == "ab" and arm == "B"
    command = [str(root / "P1kBenchmark.x86_64"), "--headless", "--fixed-fps", "60",
               "--log-file", str(folder / "engine.log"), "--", "--samples=600", "--warmup=120",
               "--pace-usec=16667", "--naval-test-accounts", f"--naval-data={folder / 'data'}"]
    if pilot: command.append("--pilot")
    with (folder / "stdout.log").open("wb") as log:
        run = subprocess.run(command, cwd=root, stdout=log, stderr=subprocess.STDOUT, timeout=150,
                             env=dict(os.environ, XDG_DATA_HOME=str(folder)))
    log = (folder / "stdout.log").read_text(encoding="utf-8", errors="replace")
    rows = [json.loads(line.removeprefix("P1K_COST ")) for line in log.splitlines() if line.startswith("P1K_COST ")]
    if run.returncode or "ERROR:" in log or "P1K_EXPORT_ENTRY release=true qa=true" not in log.splitlines() or len(rows) != 1:
        raise RuntimeError(f"{mode} {pair}/{arm} failed: {log[-1200:]}")
    row = rows[0]
    if not row["pass"] or row["pilot"] != pilot or row["water_checks"] != 28*720 or row["water_errors"]:
        raise RuntimeError("workload or authority mismatch")
    samples = sorted(row["raw_ms"])
    if len(samples) != 600 or any(not math.isfinite(x) or x <= 0 for x in samples):
        raise RuntimeError("invalid samples")
    row["metrics_ms"] = {key: samples[int((len(samples)-1)*q)] for key,q in (("p50",.5),("p95",.95),("p99",.99))}
    row["metrics_ms"]["mean"] = statistics.mean(samples)
    row.update(pair=pair, arm=arm)
    print(f"{mode} {pair}/{arm}: {row['metrics_ms']}", flush=True)
    return row

def run(mode, control=None):
    trials, deltas = [], []
    for pair in range(5):
        group = {}
        for arm in (("A", "B") if pair % 2 == 0 else ("B", "A")):
            group[arm] = trial(mode, pair, arm)
            trials.append(group[arm])
        for key in ("state_sha256", "visual_updates", "water_checks", "water_errors"):
            if group["A"][key] != group["B"][key]: raise RuntimeError(f"different {key}")
        deltas.append({key: 100*(group["B"]["metrics_ms"][key]/value-1)
                       for key,value in group["A"]["metrics_ms"].items()})
    medians = {key: statistics.median(row[key] for row in deltas) for key in deltas[0]}
    noise = {key: max(abs(row[key]) for row in deltas) for key in ("p50", "p99")}
    valid_control = bool(control and control["status"] == "pass_control")
    budget = medians["p50"] <= 0 and medians["p99"] <= 5
    status = ("pass_control" if all(v <= 5 for v in noise.values()) else "inconclusive_control") if mode == "aa" else (
             "regression_observed" if not budget else ("pass_cpu_fixture" if valid_control else "inconclusive_control"))
    result = {"mode": mode, "status": status, "median_delta_pct": medians, "max_absolute_delta_pct": noise,
              "control_valid": valid_control, "pairs": 5, "parameters": parameters, "host": host,
              "exe_sha256": manifest["exe_sha256"], "pack_sha256": manifest["pack_sha256"],
              "source_sha256": manifest["gameplay_sha256"], "fixtures_sha256": manifest["fixtures_sha256"],
              "trials": trials, "paired_delta_pct": deltas}
    (root / f"{mode}.json").write_text(json.dumps(result, indent=2))
    print(json.dumps({k:result[k] for k in ("mode","status","median_delta_pct","max_absolute_delta_pct","control_valid")}), flush=True)
    return result

control=run("aa")
run("ab",control)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--identity-root", type=Path, required=True,
                        help="Main checkout containing distribution/private and work/ssh-runtime")
    parser.add_argument("--host", required=True)
    parser.add_argument("--user", required=True)
    args = parser.parse_args()
    build = args.build.resolve()
    manifest = json.loads((build / "p1k_export.json").read_text(encoding="utf-8"))
    executable = build / "P1kBenchmark.x86_64"
    pack = build / "P1kBenchmark.pck"
    if (file_hash(executable) != manifest["exe_sha256"] or file_hash(pack) != manifest["pack_sha256"]
            or file_hash(ROOT / "project.godot") != manifest["project_sha256"]
            or file_hash(ROOT / "export_presets.cfg") != manifest["export_presets_sha256"]
            or gameplay_hashes() != manifest["gameplay_sha256"]
            or {name: sha256(data).hexdigest() for name,data in benchmark_sources().items()} != manifest["fixtures_sha256"]):
        raise RuntimeError("Export or source does not match the manifest")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    sys.path.insert(0, str(args.identity_root.resolve() / "work/ssh-runtime"))
    import paramiko
    client = paramiko.SSHClient()
    client.load_host_keys(str(args.identity_root / "distribution/private/ubuntu_known_hosts"))
    client.set_missing_host_key_policy(paramiko.RejectPolicy())
    client.connect(args.host, username=args.user,
                   key_filename=str(args.identity_root / "distribution/private/ubuntu_deploy_rsa"),
                   look_for_keys=False, allow_agent=False, timeout=15)
    remote = "/tmp/toque-p1k-" + uuid.uuid4().hex
    try:
        with client.open_sftp() as sftp:
            sftp.mkdir(remote, 0o700)
            for source in (executable, pack, build / "p1k_export.json"):
                sftp.put(str(source), remote + "/" + source.name)
            with sftp.file(remote + "/benchmark.py", "w") as stream:
                stream.write(REMOTE_PROGRAM)
            sftp.chmod(remote + "/P1kBenchmark.x86_64", 0o700)
        command = "cd " + shlex.quote(remote) + " && sha256sum P1kBenchmark.x86_64 P1kBenchmark.pck"
        _, stdout, stderr = client.exec_command(command, timeout=60)
        hashes = stdout.read().decode().splitlines()
        if stdout.channel.recv_exit_status() or len(hashes) != 2 or hashes[0].split()[0] != manifest["exe_sha256"] or hashes[1].split()[0] != manifest["pack_sha256"]:
            raise RuntimeError("Remote upload hash verification failed")
        print("Remote isolated QA directory:", remote, flush=True)
        _, stdout, stderr = client.exec_command("cd " + shlex.quote(remote) + " && nice -n 19 python3 -u benchmark.py", timeout=900)
        for line in iter(stdout.readline, ""):
            print(line, end="", flush=True)
        error = stderr.read().decode("utf-8", errors="replace")
        if stdout.channel.recv_exit_status():
            raise RuntimeError(f"Remote benchmark failed: {error[-3000:]}")
        with client.open_sftp() as sftp:
            for name in ("aa.json", "ab.json"):
                sftp.get(remote + "/" + name, str(output / name))
        for name in ("aa.json", "ab.json"):
            report = json.loads((output / name).read_text(encoding="utf-8"))
            if report["exe_sha256"] != manifest["exe_sha256"] or report["pack_sha256"] != manifest["pack_sha256"]:
                raise RuntimeError("Returned report does not match the export")
        print("Evidence:", output, flush=True)
    finally:
        client.close()


if __name__ == "__main__":
    main()
