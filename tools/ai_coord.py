#!/usr/bin/env python3
"""Coordenacao de IAs por arquivos: reservas, hashes, backups e handoffs.
Uso: python tools/ai_coord.py --help
Sem dependencia de Git ou bibliotecas externas.
"""
import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parent.parent

def find_git():
    candidates = [shutil.which("git"), r"C:\Program Files\Git\cmd\git.exe"]
    return next((str(c) for c in candidates if c and Path(c).is_file()), None)

def shared_home():
    executable = find_git()
    if executable:
        result = subprocess.run(
            [executable, "-C", str(ROOT), "rev-parse", "--git-common-dir"],
            capture_output=True, text=True, check=False
        )
        if result.returncode == 0:
            location = Path(result.stdout.strip())
            common_dir = (location if location.is_absolute() else ROOT / location).resolve()
            return common_dir.parent / ".ai-coord"
    return ROOT / ".ai-coord"

HOME = shared_home()
REG = HOME / "registry.json"
LOCK = HOME / "registry.lock"
BACKUPS = HOME / "backups"
MAX_BACKUP_BYTES = 64 * 1024 * 1024


def now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def rel_file(value):
    raw = Path(value)
    if value.endswith(("/", "\\")):
        raise ValueError("Reserve arquivos especificos, nao diretorios: " + value)
    resolved = (raw if raw.is_absolute() else ROOT / raw).resolve()
    try:
        rel = resolved.relative_to(ROOT.resolve())
    except ValueError:
        raise ValueError("Caminho fora do projeto: " + value)
    if not rel.parts or rel.parts[0].lower() in (".ai-coord", ".git"):
        raise ValueError("Caminho reservado/invalido: " + value)
    if resolved.exists() and not resolved.is_file():
        raise ValueError("Nao e um arquivo regular: " + value)
    return rel.as_posix()


def digest(relative, workspace=None):
    path = (workspace or ROOT) / relative
    return digest_path(path)


def digest_path(path):
    if not path.exists():
        return None
    before = path.stat()
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    after = path.stat()
    if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
        raise RuntimeError("Arquivo mudou DURANTE a leitura: " + relative)
    return h.hexdigest()


def read_registry():
    if not REG.exists():
        return {"version": 1, "sessions": {}}
    data = json.loads(REG.read_text(encoding="utf-8"))
    if data.get("version") != 1 or not isinstance(data.get("sessions"), dict):
        raise RuntimeError("Formato de registro desconhecido; nenhuma escrita realizada")
    return data


def save_registry(data):
    temp = HOME / ("registry-" + uuid.uuid4().hex + ".tmp")
    try:
        with temp.open("x", encoding="utf-8", newline="\n") as stream:
            json.dump(data, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp, REG)
    finally:
        temp.unlink(missing_ok=True)


@contextmanager
def mutex():
    HOME.mkdir(exist_ok=True)
    (HOME / ".gdignore").touch(exist_ok=True)
    handle = None
    for _ in range(50):
        try:
            handle = os.open(str(LOCK), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            os.write(handle, (str(os.getpid()) + " " + now()).encode())
            break
        except FileExistsError:
            time.sleep(0.1)
    if handle is None:
        raise RuntimeError("Registro ocupado ou lock preso: " + str(LOCK))
    try:
        yield
    finally:
        os.close(handle)
        LOCK.unlink(missing_ok=True)


def session(data, sid):
    task = data["sessions"].get(sid)
    if task is None:
        raise ValueError("Sessao desconhecida: " + sid)
    if task["status"] != "active":
        raise ValueError("Sessao nao ativa (" + task["status"] + "): " + sid)
    workspace = Path(task.get("workspace", str(HOME.parent.resolve()))).resolve()
    if workspace != ROOT.resolve():
        raise ValueError("Sessao pertence a outra worktree: " + str(workspace))
    return task


def snapshot(relative, sid, hash_before):
    if hash_before is None:
        return False
    original = ROOT / relative
    if original.stat().st_size > MAX_BACKUP_BYTES:
        return False
    target = BACKUPS / sid / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(original, target)
    if digest(relative) != hash_before or digest_path(target) != hash_before:
        target.unlink(missing_ok=True)
        raise RuntimeError("Arquivo mudou durante o backup; reserva cancelada: " + relative)
    return True


def cmd_start(args):
    paths = list(dict.fromkeys(rel_file(p) for p in args.files))
    with mutex():
        data = read_registry()
        for sid, task in data["sessions"].items():
            if task["status"] == "active":
                same_workspace = Path(task.get("workspace", str(HOME.parent.resolve()))).resolve() == ROOT.resolve()
                overlap = sorted(set(paths) & set(task["files"])) if same_workspace else []
                if overlap:
                    raise RuntimeError(
                        "CONFLITO: " + ", ".join(overlap) + " reservado por " + sid
                        + " (" + task["agent"] + ": " + task["title"] + ")"
                    )
        sid = datetime.now().strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:8]
        files = {}
        try:
            for relative in paths:
                before = digest(relative)
                backed_up = snapshot(relative, sid, before)
                files[relative] = {
                    "baseline_sha256": before, "expected_sha256": before,
                    "backup": backed_up
                }
            data["sessions"][sid] = {
                "agent": args.agent, "title": args.task, "status": "active",
                "workspace": str(ROOT.resolve()),
                "started_at": now(), "finished_at": None,
                "notes": "", "files": files, "events": []
            }
            save_registry(data)
        except Exception:
            shutil.rmtree(BACKUPS / sid, ignore_errors=True)
            raise
    print("SESSAO " + sid)
    print("Arquivos reservados: " + ", ".join(paths))
    print("Backups (ate 64 MiB/arquivo): " + str(sum(1 for f in files.values() if f["backup"])))
    print("Antes de CADA nova rodada de edicao: check. Apos edicao propria: checkpoint.")


def differences(task):
    result = []
    workspace = Path(task.get("workspace", str(HOME.parent.resolve()))).resolve()
    for path, record in task["files"].items():
        actual = digest(path, workspace=workspace)
        if record["expected_sha256"] != actual:
            result.append((path, record["expected_sha256"], actual))
    return result


def cmd_check(args):
    data = read_registry()
    task = session(data, args.id)
    changes = differences(task)
    if changes:
        print("BLOQUEADO: hashes alterados desde ultimo checkpoint!")
        for path, expected, actual in changes:
            print("  " + path + "\n    esperado=" + str(expected) + "\n    atual=" + str(actual))
        return 2
    print("OK: " + args.id + " | " + str(len(task["files"])) + " arquivos intactos")
    return 0


def cmd_checkpoint(args):
    if not args.confirm_own_changes:
        raise ValueError("Exige --confirm-own-changes (nunca aceite mudancas de outra IA)")
    with mutex():
        data = read_registry()
        task = session(data, args.id)
        changes = []
        for relative, item in task["files"].items():
            new_hash = digest(relative)
            if new_hash != item["expected_sha256"]:
                changes.append({"file": relative, "from": item["expected_sha256"], "to": new_hash})
                item["expected_sha256"] = new_hash
        task["events"].append({"time": now(), "type": "checkpoint", "changes": changes,
                               "note": args.note or ""})
        if args.note:
            task["notes"] = args.note
        save_registry(data)
    print("CHECKPOINT " + args.id + " | arquivos atualizados: " + str(len(changes)))
    for change in changes:
        print("  " + change["file"])


def cmd_finish(args):
    with mutex():
        data = read_registry()
        task = session(data, args.id)
        changes = differences(task)
        if changes:
            raise RuntimeError("Hashes nao conferem: " + ", ".join(c[0] for c in changes)
                               + ". Confira a origem antes do checkpoint.")
        task["status"] = "completed"
        task["finished_at"] = now()
        task["notes"] = args.notes
        task["events"].append({"time": now(), "type": "completed", "note": args.notes})
        save_registry(data)
        edited = [p for p, f in task["files"].items()
                  if digest(p) != f["baseline_sha256"]]
    print("CONCLUIDO " + args.id)
    print("Modificados desde a reserva: " + (", ".join(edited) if edited else "nenhum"))
    print("Proximas IAs podem consultar o historico com: status")


def cmd_abort(args):
    with mutex():
        data = read_registry()
        task = session(data, args.id)
        task["status"] = "aborted"
        task["finished_at"] = now()
        task["notes"] = args.notes
        task["events"].append({"time": now(), "type": "aborted", "note": args.notes})
        save_registry(data)
    print("RESERVAS LIBERADAS SEM REVERTER ARQUIVOS: " + args.id)


def cmd_status(args):
    data = read_registry()
    tasks = list(data["sessions"].items())
    active = [(sid, t) for sid, t in tasks if t["status"] == "active"]
    print("WORKTREE: " + str(ROOT))
    print("REGISTRO COMPARTILHADO: " + str(REG))
    print("Sessoes ativas: " + str(len(active)) + " | historico total: " + str(len(tasks)))
    for sid, task in active:
        try:
            changes = differences(task)
            health = "ALERTA HASH" if changes else "OK"
        except Exception as exc:
            health = "ERRO AO LER: " + str(exc)
        print("\n[ATIVO][" + health + "] " + sid + " | " + task["agent"] + " | " + task["title"])
        print("  Arquivos: " + ", ".join(task["files"]))
        print("  Worktree: " + task.get("workspace", str(HOME.parent.resolve())))
        print("  Inicio: " + task["started_at"])
        if task["notes"]:
            print("  Nota: " + task["notes"])
    closed = [(sid, t) for sid, t in tasks if t["status"] != "active"]
    print("\nULTIMOS ENCERRADOS:")
    for sid, task in reversed(closed[-args.limit:]):
        print("  " + task["status"].upper() + " " + sid + " | " + task["title"]
              + " | " + (task["notes"] or "sem resumo"))
    if not closed:
        print("  Nenhum")
    print("\nRegra: sessao ativa nao e arquivo livre; hashes alterados exigem investigacao.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    start = sub.add_parser("start", help="Reserva arquivos e tira snapshot antes de editar")
    start.add_argument("--agent", required=True, help="Identificador desta IA/chat")
    start.add_argument("--task", required=True, help="Objetivo da mudanca")
    start.add_argument("files", nargs="+", help="Arquivos RELATIVOS ex.: scripts/weapon.gd")
    start.set_defaults(fn=cmd_start)
    check = sub.add_parser("check", help="Detecta alteracoes externas desde o checkpoint")
    check.add_argument("id")
    check.set_defaults(fn=cmd_check)
    cp = sub.add_parser("checkpoint", help="Atualiza hashes APENAS apos suas proprias edicoes")
    cp.add_argument("id")
    cp.add_argument("--confirm-own-changes", action="store_true", required=True)
    cp.add_argument("--note", default="")
    cp.set_defaults(fn=cmd_checkpoint)
    finish = sub.add_parser("finish", help="Conclui e libera arquivos; nao publica build")
    finish.add_argument("id")
    finish.add_argument("--notes", required=True)
    finish.set_defaults(fn=cmd_finish)
    abort = sub.add_parser("abort", help="Libera reserva sem restaurar backups")
    abort.add_argument("id")
    abort.add_argument("--notes", required=True)
    abort.set_defaults(fn=cmd_abort)
    status = sub.add_parser("status", help="Mostra sessao e contexto de trabalho de outras IAs")
    status.add_argument("--limit", type=int, default=8)
    status.set_defaults(fn=cmd_status)
    args = parser.parse_args()
    try:
        code = args.fn(args)
        return code if isinstance(code, int) else 0
    except (OSError, RuntimeError, ValueError, json.JSONDecodeError) as exc:
        print("ERRO: " + str(exc), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
