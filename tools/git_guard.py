#!/usr/bin/env python3
"""Audita somente a versao STAGED, em lotes (rapido ate na primeira importacao).
Proibe arquivos privados, blobs grandes e marcadores obvios de credenciais.
"""
from pathlib import PurePosixPath
import re
import shutil
import subprocess
import sys

GIT = shutil.which("git") or r"C:\Program Files\Git\cmd\git.exe"
MAX_BYTES = 50 * 1024 * 1024
MAX_TEXT_SCAN = 2 * 1024 * 1024
BAD_DIRS = (
    "work/", "user_data/", ".ai-coord/", ".godot/",
    "distribution/build/", "distribution/published/", "distribution/private/"
)
BAD_PARTS = (".godot", ".git", ".ai-coord", "__pycache__", ".import")
BAD_NAMES = ("device-private.pem", "id_rsa", "id_ed25519")
BAD_EXT = (".p12", ".pfx", ".p8", ".ppk", ".jks", ".keystore", ".key",
           ".sqlite", ".sqlite3", ".db", ".exe", ".pck", ".dmp")
PUBLIC_PEM = {"assets/accounts/accounts-public.pem", "distribution/launcher/release-public.pem"}
TEXT_EXT = (".gd", ".tscn", ".tres", ".godot", ".gdshader", ".py", ".json",
            ".md", ".yaml", ".yml", ".sh", ".ps1", ".cfg", ".txt", ".xml",
            ".php", ".js", ".ts", ".html", ".css", ".bat", ".cmd", ".csv")
SECRETS = (
    ("chave privada", re.compile(rb"-----BEGIN\s+(?:OPENSSH|RSA|EC|DSA|ENCRYPTED)?\s*PRIVATE KEY-----")),
    ("token GitHub", re.compile(rb"(?:ghp_|gho_|ghu_|ghs_|ghr_)[A-Za-z0-9]{25,}|github_pat_[A-Za-z0-9_]{35,}")),
    ("token Slack", re.compile(rb"xox[baprs]-[A-Za-z0-9-]{20,}")),
    ("chave AWS", re.compile(rb"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b")),
    ("chave Google API", re.compile(rb"\bAIza[0-9A-Za-z_\-]{35}\b")),
    ("senha em URL", re.compile(rb"\b(?:https?|postgres(?:ql)?|mysql)://[^\s/@]{2,}:[^\s/@]{2,}@[^\s/]{3,}", re.I)),
)


def git(*args, input_bytes=None):
    cp = subprocess.run([GIT, *args], input=input_bytes, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if cp.returncode:
        raise RuntimeError(cp.stderr.decode("utf-8", errors="replace").strip())
    return cp.stdout


def invalid_path(p):
    low = p.casefold()
    parts = [s.casefold() for s in PurePosixPath(p).parts]
    name = parts[-1]
    if any(low.startswith(prefix) for prefix in BAD_DIRS):
        return "diretorio privado/gerado"
    if any(part in BAD_PARTS for part in parts):
        return "cache/estado de ferramenta"
    if ((name.startswith(".env") and name != ".env.example")
            or any(key in name for key in BAD_NAMES)
            or any(name.endswith(ext) for ext in BAD_EXT)):
        return "arquivo privado, ambiente ou gerado"
    if name.endswith(".pem") and p not in PUBLIC_PEM:
        return "PEM nao autorizado"
    if any(tag in name for tag in ("-private.", "-secret.", "-credential.", "-credentials.", "-token.")):
        return "nome que indica credencial"
    if name.endswith((".log", ".tmp", ".bak")):
        return "log/temporario"
    return None


def staged_oids():
    result = {}
    for entry in git("ls-files", "--stage", "-z").split(b"\0"):
        if not entry:
            continue
        head, path = entry.split(b"\t", 1)
        _, oid, stage = head.split()
        if stage == b"0":
            result[path.decode("utf-8", errors="surrogateescape")] = oid.decode("ascii")
    return result


def sizes_for(oids):
    unique = list(dict.fromkeys(oids))
    if not unique:
        return {}
    output = git("cat-file", "--batch-check=%(objectname) %(objectsize)",
                 input_bytes=("\n".join(unique) + "\n").encode("ascii"))
    sizes = {}
    for line in output.splitlines():
        oid, size = line.decode("ascii").split()
        sizes[oid] = int(size)
    return sizes


def contents_for(oids):
    unique = list(dict.fromkeys(oids))
    if not unique:
        return {}
    output = git("cat-file", "--batch", input_bytes=("\n".join(unique) + "\n").encode("ascii"))
    result, pos = {}, 0
    for oid in unique:
        end = output.find(b"\n", pos)
        if end < 0:
            raise RuntimeError("Respostas incompletas de git cat-file --batch")
        header = output[pos:end].split()
        if len(header) != 3 or header[0].decode("ascii") != oid or header[1] != b"blob":
            raise RuntimeError("Blob Git inesperado: " + oid)
        length = int(header[2])
        result[oid] = output[end+1:end+1+length]
        pos = end + 1 + length + 1
    return result


def scan():
    paths = [v.decode("utf-8", errors="surrogateescape") for v in
             git("diff", "--cached", "--name-only", "--diff-filter=ACMR", "-z").split(b"\0") if v]
    index = staged_oids()
    problems, valid = [], []
    for path in paths:
        reason = invalid_path(path)
        if reason:
            problems.append(f"{path}: {reason}")
        elif path not in index:
            problems.append(f"{path}: arquivo staged sem blob verificavel")
        else:
            valid.append(path)
    sizes = sizes_for([index[p] for p in valid])
    total = 0
    text_paths = []
    for path in valid:
        oid = index[path]
        size = sizes[oid]
        total += size
        if size > MAX_BYTES:
            problems.append(f"{path}: {size/1048576:.1f} MiB (limite 50 MiB)")
        elif size <= MAX_TEXT_SCAN and path.lower().endswith(TEXT_EXT):
            text_paths.append(path)
    blobs = contents_for([index[p] for p in text_paths])
    for path in text_paths:
        data = blobs[index[path]]
        for label, regex in SECRETS:
            if regex.search(data):
                problems.append(f"{path}: possivel segredo ({label})")
    if problems:
        print("GIT GUARD: COMMIT BLOQUEADO, sem apagar arquivos.", file=sys.stderr)
        for item in problems:
            print(" - " + item, file=sys.stderr)
        return 2
    print(f"GIT GUARD: OK ({len(paths)} arquivos staged, {total/1048576:.1f} MiB).")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(scan())
    except Exception as exc:
        print("GIT GUARD: falha de auditoria, commit bloqueado: " + str(exc), file=sys.stderr)
        sys.exit(2)
