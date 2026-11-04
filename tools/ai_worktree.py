#!/usr/bin/env python3
"""Cria worktrees isoladas para IAs, mantendo um unico Git local."""
import argparse
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
GIT = shutil.which("git") or r"C:\Program Files\Git\cmd\git.exe"


def run(*args, capture=True):
    command = [GIT, "-C", str(ROOT), *map(str, args)]
    result = subprocess.run(command, capture_output=capture, text=True, check=False)
    if result.returncode:
        raise RuntimeError("Git falhou: " + " ".join(args) + "\n" + (result.stderr or result.stdout or ""))
    return result.stdout.strip() if capture else ""


def home():
    location = Path(run("rev-parse", "--git-common-dir"))
    return (location if location.is_absolute() else ROOT / location).resolve().parent


def show(_):
    print(run("worktree", "list"))
    print("\nCada pasta tem seus proprios arquivos. Todas pertencem ao mesmo Git local.")
    print("Contexto de reservas centralizado em: " + str(home() / ".ai-coord"))


def create(args):
    label = args.name.strip().lower()
    if not re.fullmatch(r"[a-z][a-z0-9_-]{1,31}", label):
        raise ValueError("Use nome simples com 2 a 32 caracteres: audio, mapas, bots, hud, armas, etc.")
    main = home()
    target = main.parents[1] / "campo-worktrees" / label
    branch = "ia/" + label
    if target.exists():
        raise FileExistsError("Pasta de trabalho ja existe: " + str(target))
    if run("status", "--porcelain"):
        raise RuntimeError("Worktree atual tem modificacoes nao commitadas. Revise antes de criar uma nova.")
    run("rev-parse", "--verify", "refs/heads/main")
    target.parent.mkdir(parents=True, exist_ok=True)
    print("Criando branch " + branch + " em " + str(target))
    run("worktree", "add", "-b", branch, str(target), "main")
    print("PRONTA: " + str(target))
    print("Abra esta pasta no chat/IDE da IA; nao use o diretorio MAIN durante a implementacao.")
    print("Ao terminar: commit na branch, teste, revise diff e integre manualmente no MAIN.")
    print("Reservas/estado: python tools/ai_coord.py status")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)
    listing = sub.add_parser("list", help="Lista pastas/branches")
    listing.set_defaults(fn=show)
    new = sub.add_parser("create", help="Cria branch ia/NOME + pasta fisica isolada")
    new.add_argument("name", help="Identificador (ex.: audio, mapas, hud)")
    new.set_defaults(fn=create)
    args = parser.parse_args()
    try:
        args.fn(args)
        return 0
    except (OSError, ValueError, RuntimeError) as exc:
        print("ERRO: " + str(exc), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
