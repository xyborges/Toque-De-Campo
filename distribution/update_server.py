"""Read-only LAN update server; exposes only public release artifacts."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit
import argparse
import json
import re
import shutil
import urllib.request

PUBLIC = Path(__file__).resolve().parent / 'published'
PAGE = '''<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>Toque de Campo</title><body style="background:#091c22;color:#eaf2eb;font:20px system-ui;max-width:700px;margin:12vh auto;padding:24px">
<h1 style="color:#cbfa68">Toque de Campo</h1><p>Baixe uma vez. O aplicativo verifica e instala as novas versões ao abrir.</p>
<p><a style="display:inline-block;background:#cbfa68;color:#091c22;padding:18px;border-radius:12px;text-decoration:none" href="/ToqueDeCampo.exe">Baixar para Windows 64 bits</a></p>
<p>Abra o executável, aguarde a primeira instalação e entre no servidor <strong>192.168.101.227</strong>.</p>
<p style="font-size:16px">No modo naval, clique em Criar sala neste PC: o jogo hospeda automaticamente. Os amigos encontram a sala pela busca na rede local ou pelo endereço IP:porta do lobby.</p></body></html>'''.encode()

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = urlsplit(self.path).path
        if path == '/health':
            return self.send_bytes(b'{"service":"toque-de-campo-updates"}', 'application/json')
        if path == '/': return self.send_bytes(PAGE, 'text/html; charset=utf-8')
        if path == '/manifest.json': target, mime = PUBLIC / 'manifest.json', 'application/json'
        elif path == '/ToqueDeCampo.exe': target, mime = PUBLIC / 'ToqueDeCampo.exe', 'application/octet-stream'
        elif re.fullmatch(r'/releases/game-[1-9][0-9]*-[a-f0-9]{12}\.zip', path):
            target, mime = PUBLIC / path.lstrip('/'), 'application/zip'
        else:
            self.send_error(404)
            return
        if not target.is_file():
            self.send_error(404)
            return
        try:
            with target.open('rb') as source:
                self.send_response(200)
                self.send_header('Content-Type', mime)
                self.send_header('Content-Length', str(target.stat().st_size))
                self.send_header('Cache-Control', 'no-store')
                self.send_header('X-Content-Type-Options', 'nosniff')
                self.end_headers()
                shutil.copyfileobj(source, self.wfile, length=1024 * 1024)
        except (ConnectionResetError, BrokenPipeError, ConnectionAbortedError): pass

    def send_bytes(self, data, mime):
        self.send_response(200)
        self.send_header('Content-Type', mime)
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(data)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=8088)
    args = parser.parse_args()
    try:
        with urllib.request.urlopen(f'http://127.0.0.1:{args.port}/health', timeout=1) as response:
            if json.load(response).get('service') == 'toque-de-campo-updates':
                raise SystemExit('O servidor de atualizacoes ja esta aberto. Nenhum segundo servidor foi criado.')
    except (OSError, ValueError): pass
    print(f'Atualizacoes: http://192.168.101.227:{args.port}', flush=True)
    print('Mantenha esta janela aberta. A partida usa outra porta: UDP 3010.', flush=True)
    try:
        ThreadingHTTPServer(('0.0.0.0', args.port), Handler).serve_forever()
    except OSError as error:
        raise SystemExit(f'Nao foi possivel abrir a porta {args.port}: {error}')
