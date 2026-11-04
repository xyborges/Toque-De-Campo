"""Create the complete static XAMPP download folder (no Python on web requests)."""
from pathlib import Path
import json
import os
import shutil
from publish import DEFAULT_GODOT, run
from update_server import PAGE

ROOT = Path(__file__).resolve().parent

def prepare(godot=DEFAULT_GODOT, rebuild_launcher=False):
    source = ROOT / 'published'
    target = ROOT / 'xampp' / 'toque-de-campo'
    (target / 'releases').mkdir(parents=True, exist_ok=True)
    # API source is public; its database and private keys remain outside htdocs.
    (target / 'accounts').mkdir(exist_ok=True)
    shutil.copy2(ROOT.parent / 'account-service' / 'api.php', target / 'accounts' / 'api.php')
    (target / 'accounts' / '.htaccess').write_text('Options -Indexes\n', encoding='ascii')
    if rebuild_launcher or not (target / 'ToqueDeCampo.exe').exists():
        run(godot, '--path', ROOT / 'launcher', '--export-release', 'Windows XAMPP', target / 'ToqueDeCampo.exe')
    # Use only the public artifacts; never copy keys, profiles or local installations.
    for archive in (source / 'releases').glob('game-*.zip'):
        shutil.copy2(archive, target / 'releases' / archive.name)
    shutil.copy2(source / 'manifest.json', target / 'manifest.json')
    (target / 'index.html').write_bytes(PAGE.replace(b'href="/ToqueDeCampo.exe"', b'href="ToqueDeCampo.exe"'))
    (target / '.htaccess').write_text('Options -Indexes\n<IfModule mod_headers.c>\n<Files "manifest.json">\nHeader set Cache-Control "no-store"\n</Files>\n</IfModule>\n', encoding='ascii')
    print('Pasta para copiar ao XAMPP:', target)
    print('Destino: C:/xampp/htdocs/toque-de-campo')
    print('URL: http://192.168.101.227/toque-de-campo/')
    config_path = ROOT / 'deploy-config.json'
    if config_path.exists():
        config = json.loads(config_path.read_text(encoding='utf-8'))
        destination = Path(config['xampp_directory']).resolve()
        # Copy a fixed public allowlist; never mirror the source tree or secrets.
        destination.mkdir(parents=True, exist_ok=True)
        (destination / 'releases').mkdir(exist_ok=True)
        (destination / 'accounts').mkdir(exist_ok=True)
        for name in ('api.php', '.htaccess'):
            shutil.copy2(target / 'accounts' / name, destination / 'accounts' / (name + '.tmp'))
            os.replace(destination / 'accounts' / (name + '.tmp'), destination / 'accounts' / name)
        for archive in (target / 'releases').glob('game-*.zip'):
            if not (destination / 'releases' / archive.name).exists():
                shutil.copy2(archive, destination / 'releases' / (archive.name + '.tmp'))
                os.replace(destination / 'releases' / (archive.name + '.tmp'), destination / 'releases' / archive.name)
        for name in ('index.html', 'ToqueDeCampo.exe', '.htaccess', 'manifest.json'):
            shutil.copy2(target / name, destination / (name + '.tmp'))
            os.replace(destination / (name + '.tmp'), destination / name)
        print('Publicado no XAMPP:', destination)
    return target

if __name__ == '__main__': prepare(rebuild_launcher=True)
