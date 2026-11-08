#!/usr/bin/env python3
"""Gate leve de CI GitHub: audita arquivos rastreados (sem executar Godot nem publicar build).

Diferente do hook pre-commit, verifica o CHECKOUT INTEIRO, nao apenas o stage.
"""
from pathlib import Path
import subprocess
import sys

import git_guard

ROOT = Path(__file__).resolve().parent.parent
MAX_TEXT_SCAN = 2 * 1024 * 1024


def tracked_files():
    proc = subprocess.run([git_guard.GIT, "-C", str(ROOT), "ls-files", "-z"],
                          capture_output=True, check=True)
    return [part.decode("utf-8", "surrogateescape")
            for part in proc.stdout.split(b"\x00") if part]


def validate():
    problems = []
    checked_bytes = 0
    entries = tracked_files()
    for relative in entries:
        path = ROOT / relative
        issue = git_guard.invalid_path(relative)
        if issue:
            problems.append(f"{relative}: {issue}")
            continue
        if path.is_symlink():
            problems.append(f"{relative}: symlink proibido por padrao; requer revisao")
            continue
        if not path.is_file():
            problems.append(f"{relative}: arquivo esperado nao encontrado")
            continue
        size = path.stat().st_size
        checked_bytes += size
        if size > git_guard.MAX_BYTES:
            problems.append(f"{relative}: {size/1048576:.1f} MiB (limite 50 MiB)")
            continue
        if size <= MAX_TEXT_SCAN and relative.lower().endswith(git_guard.TEXT_EXT):
            contents = path.read_bytes()
            for name, pattern in git_guard.SECRETS:
                if pattern.search(contents):
                    problems.append(f"{relative}: possivel credencial ({name})")
    for essential in ("AGENTS.md", "project.godot", "docs/FLUXO-GITHUB-OFICIAL.md"):
        if essential not in entries:
            problems.append(f"{essential}: arquivo de projeto/regras ausente")
    if problems:
        print(f"PREFLIGHT GITHUB: FALHOU ({len(problems)} problemas)")
        for issue in problems[:80]:
            print("  - " + issue)
        if len(problems) > 80:
            print(f"  ... e mais {len(problems)-80} problemas")
        return 2
    print(f"PREFLIGHT GITHUB: OK | {len(entries)} arquivos | "
          f"{checked_bytes / 1048576:.1f} MiB | sem segredos obvios detectados")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(validate())
    except (OSError, RuntimeError, subprocess.CalledProcessError) as exc:
        print("PREFLIGHT GITHUB: erro de auditoria: " + str(exc), file=sys.stderr)
        sys.exit(2)
