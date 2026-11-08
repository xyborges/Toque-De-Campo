#!/usr/bin/env python3
"""Cria worktrees para IAs SEM editar a main. Base oficial: origin/main (GitHub).

Exemplos:
    python tools/ai_worktree.py list
    python tools/ai_worktree.py create favela-lajes
    python tools/ai_worktree.py sync-main    # SOMENTE no checkout main limpo
"""
import argparse
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
GIT = shutil.which("git") or r"C:\Program Files\Git\cmd\git.exe"
EXPECTED = "github.com/xyborges/Toque-De-Campo"


def run(*args, check=True):
    cmd = [GIT, "-C", str(ROOT), *map(str, args)]
    proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8",
                          errors="replace", check=False)
    if check and proc.returncode:
        raise RuntimeError("Git falhou: " + " ".join(map(str, args))
                           + "\n" + (proc.stderr or proc.stdout).strip())
    return proc


def output(*args):
    return run(*args).stdout.strip()


def official_remote():
    url = output("remote", "get-url", "origin")
    normalized = url.lower().replace("\\", "/").replace(":", "/")
    if EXPECTED.lower() not in normalized:
        raise RuntimeError("origin nao corresponde ao GitHub oficial: " + url)
    return url


def main_checkout():
    location = Path(output("rev-parse", "--git-common-dir"))
    folder = (location if location.is_absolute() else ROOT / location).resolve()
    return folder.parent


def slug(text):
    value = text.lower().strip()
    if not re.fullmatch(r"[a-z0-9][a-z0-9_-]{1,29}", value):
        raise ValueError("Use 2-30 caracteres [a-z0-9_-], ex.: favela-lajes-v25")
    return value


def host_slug():
    value = re.sub(r"[^a-z0-9]+", "-", platform.node().lower()).strip("-")
    return value[:26] or "pc"


def show(_):
    print("ORIGIN: " + official_remote())
    print("Worktree atual: " + str(ROOT))
    print("GitHub origin/main local: " + output("rev-parse", "--short", "refs/remotes/origin/main"))
    print("Git status: " + output("status", "-sb"))
    print("Worktrees locais (cada PC tem seu proprio registro):")
    print(output("worktree", "list"))
    print("Reservas locais: " + str(main_checkout() / ".ai-coord"))
    print("IMPORTANTE: reservas locais NAO sao visiveis pelo outro computador.")


def create(args):
    official_remote()
    name = slug(args.name)
    host = host_slug()
    branch = f"ia/{host}-{name}"
    target = main_checkout().parent / "campo-worktrees" / f"{host}-{name}"
    if target.exists():
        raise FileExistsError("Pasta ja existe: " + str(target))
    # Esta operacao atualiza APENAS refs; nao altera arquivos do checkout atual.
    print("Buscando origin/main do GitHub...")
    run("fetch", "origin", "main")
    run("rev-parse", "--verify", "refs/remotes/origin/main")
    for ref in (f"refs/heads/{branch}", f"refs/remotes/origin/{branch}"):
        if run("show-ref", "--verify", "--quiet", ref, check=False).returncode == 0:
            raise RuntimeError("Branch ja existe: " + branch + "; use nome novo.")
    target.parent.mkdir(parents=True, exist_ok=True)
    print("Criando " + branch + " desde origin/main")
    run("worktree", "add", "--no-track", "-b", branch, str(target), "origin/main")
    print("WORKTREE PRONTA: " + str(target))
    print("BRANCH: " + branch)
    print("Ao concluir: testes + commit + git push -u origin HEAD + Pull Request para main.")
    print("Nunca fazer push direto na main. Nao usar push --force.")


def sync_main(_):
    official_remote()
    branch = output("branch", "--show-current")
    if branch != "main":
        raise RuntimeError("sync-main so funciona em checkout main; branch atual: " + branch)
    if output("status", "--porcelain"):
        raise RuntimeError("main possui alteracoes nao commitadas; nao sobrescrever.")
    print("Buscando atualizacoes do GitHub...")
    run("fetch", "origin", "main")
    result = run("merge", "--ff-only", "origin/main")
    print(result.stdout.strip() or "main ja atualizada")
    print(output("status", "-sb"))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    listing = sub.add_parser("list", help="Lista worktrees e remoto oficial")
    listing.set_defaults(fn=show)
    new = sub.add_parser("create", help="Cria branch IA isolada DESDE origin/main")
    new.add_argument("name", help="Nome unico da tarefa, ex.: audio-apc-20261108")
    new.set_defaults(fn=create)
    sync = sub.add_parser("sync-main", help="Fast-forward main local limpa, sem sobrescrever")
    sync.set_defaults(fn=sync_main)
    args = parser.parse_args()
    try:
        args.fn(args)
        return 0
    except (OSError, ValueError, RuntimeError) as exc:
        print("ERRO: " + str(exc), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
