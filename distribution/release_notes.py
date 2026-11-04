"""One source of release notes for the signed installer manifest and website."""
from pathlib import Path
import html
import json

SOURCE = Path(__file__).with_name('release-notes.json')


def load_notes(version):
    notes = json.loads(SOURCE.read_text(encoding='utf-8'))
    if notes['version'] != version:
        raise ValueError('Atualize release-notes.json para a versão que será publicada.')
    if not 1 <= len(notes['changes']) <= 12:
        raise ValueError('Notas precisam ter entre 1 e 12 itens.')
    for key, limit in [('title', 120), ('summary', 600), ('date', 20)]:
        if not isinstance(notes[key], str) or not 1 <= len(notes[key]) <= limit:
            raise ValueError('Campo inválido nas notas: ' + key)
    for change in notes['changes']:
        if not isinstance(change['title'], str) or not 1 <= len(change['title']) <= 100:
            raise ValueError('Título de novidade inválido.')
        if not isinstance(change['text'], str) or not 1 <= len(change['text']) <= 600:
            raise ValueError('Descrição de novidade inválida.')
    return notes


def render_download_page(client):
    notes = client['release_notes']
    escape = html.escape
    cards = ''.join(
        '<details class="feature"><summary><span class="number">%02d</span><h3>%s</h3><span class="expand">+</span></summary><p>%s</p></details>'
        % (i + 1, escape(change['title']), escape(change['text']))
        for i, change in enumerate(notes['changes']))
    def listing(items):
        return '<ul>' + ''.join('<li>' + escape(str(item)) + '</li>' for item in items) + '</ul>' if items else '<p class="empty">Nenhum item registrado separadamente.</p>'
    history_file=Path(__file__).with_name('release-history.json')
    history=json.loads(history_file.read_text(encoding='utf-8')) if history_file.exists() else []
    current={'version':client['version_name'],'title':notes['title'],
             'additions':[item['title']+': '+item['text'] for item in notes['changes']],
             'fixes':[item['title']+': '+item['text'] for item in notes.get('fixes',[])]}
    history=[current]+[entry for entry in history if entry.get('version')!=current['version']]
    versions=''.join('<details class="version-entry"%s><summary><strong>%s</strong><span>%s</span><b>+</b></summary><div class="history-columns"><section><h3>Adições</h3>%s</section><section><h3>Correções</h3>%s</section></div></details>' %
        (' open' if i==0 else '',escape(str(entry['version'])),escape(str(entry['title'])),listing(entry.get('additions',[])),listing(entry.get('fixes',[]))) for i,entry in enumerate(history))
    return '''<!doctype html>
<html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="description" content="Baixe Toque de Campo e conheça as novidades da versão %s.">
<title>Toque de Campo · Download e novidades</title><style>
:root{color-scheme:dark;--bg:#0b1518;--panel:#132226;--line:#304145;--accent:#b7cca1;--text:#e2e9e4;--muted:#9dadae}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:16px/1.65 system-ui,sans-serif}
main{max-width:1120px;margin:auto;padding:36px 28px 60px}header{display:flex;justify-content:space-between;gap:20px;align-items:center;padding-bottom:24px;border-bottom:1px solid var(--line)}
.brand{font-weight:800;letter-spacing:.14em;color:var(--accent)}nav{display:flex;gap:22px}a{color:var(--accent)}nav a{text-decoration:none;font-size:14px}a:focus-visible{outline:3px solid var(--accent);outline-offset:5px}
.hero{padding:64px 0 48px;max-width:820px}.eyebrow,.number{font-size:12px;font-weight:700;letter-spacing:.14em;color:var(--accent)}h1{font-size:clamp(38px,7vw,70px);line-height:1.07;letter-spacing:-.035em;margin:18px 0 22px}p{color:var(--muted);margin:12px 0}
.lead{font-size:19px;max-width:700px}.download{display:inline-block;padding:17px 28px;margin:18px 0 6px;background:var(--accent);color:#15211d;font-weight:800;text-decoration:none;border:1px solid var(--accent);border-radius:5px}.download:hover{background:#cbdab9}.version{font-size:13px}.section-head{margin:12px 0 24px}h2{font-size:30px;line-height:1.2;margin:10px 0}h3{font-size:19px;line-height:1.35;margin:12px 0}
.changes{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:16px;align-items:start}.feature,.version-entry{padding:22px;border:1px solid var(--line);background:var(--panel);border-top:2px solid var(--accent);border-radius:5px}.feature summary,.version-entry summary{cursor:pointer;list-style:none}.feature summary::-webkit-details-marker,.version-entry summary::-webkit-details-marker{display:none}.feature summary{position:relative}.feature h3{padding-right:18px}.feature p{font-size:15px}.expand{position:absolute;right:0;top:0;color:var(--accent);font-size:22px}.history{margin-top:60px}.version-entry{margin:10px 0;border-top:1px solid var(--line)}.version-entry summary{display:flex;align-items:center;gap:18px}.version-entry summary strong{font-size:20px;color:var(--accent);min-width:70px}.version-entry summary span{flex:1;color:var(--text)}.version-entry summary b{color:var(--accent);font-size:22px}.history-columns{display:grid;grid-template-columns:1fr 1fr;gap:32px;border-top:1px solid var(--line);margin-top:20px}.history-columns h3{color:var(--accent)}.history-columns ul{padding-left:20px}.history-columns li{font-size:15px}.empty{font-size:14px}.how{display:grid;grid-template-columns:1fr 1fr;gap:40px;border:1px solid var(--line);padding:30px;margin-top:42px;border-radius:5px}ol{margin:0;padding-left:24px}li{padding:7px 0;color:var(--muted)}strong{color:var(--text)}footer{border-top:1px solid var(--line);margin-top:44px;padding-top:24px;color:var(--muted);font-size:13px}code{color:var(--accent)}
@media(max-width:850px){.changes{grid-template-columns:1fr 1fr}.how{grid-template-columns:1fr;gap:18px}.hero{padding-top:44px}}@media(max-width:540px){main{padding:22px 18px}.changes,.history-columns{grid-template-columns:1fr}.history-columns{gap:0}.version-entry summary{align-items:flex-start}.version-entry summary strong{min-width:52px;font-size:17px}header{align-items:flex-start;flex-direction:column}.download{width:100%%;text-align:center}.how{padding:22px}}
</style></head><body><main>
<header><span class="brand">TOQUE DE CAMPO</span><nav aria-label="Navegação"><a href="#novidades">Novidades</a><a href="#historico">Histórico</a><a href="#como-jogar">Como jogar</a></nav></header>
<section class="hero"><span class="eyebrow">ATUALIZAÇÃO %s · %s</span><h1>%s</h1><p class="lead">%s</p>
<a class="download" href="ToqueDeCampo.exe">BAIXAR PARA WINDOWS</a><p class="version">Instalador e atualizador · versão %s · build %d · atualização assinada</p>
<p>Baixe este atualizador uma vez para habilitar as conexões protegidas. Depois, use o mesmo aplicativo para receber as próximas versões.</p></section>
<section id="novidades"><div class="section-head"><span class="eyebrow">O QUE CHEGOU</span><h2>Conheça esta atualização</h2><p>Novidades para Battle Royale, Guerra, Offline e PvP.</p></div><div class="changes">%s</div></section>
<section class="history" id="historico"><div class="section-head"><span class="eyebrow">TODAS AS VERSÕES</span><h2>Histórico de atualizações</h2><p>Versões documentadas do projeto; cada registro descreve o que mudou naquela época.</p></div>%s</section>
<section class="how" id="como-jogar"><div><span class="eyebrow">PRONTO PARA ENTRAR?</span><h2>Instale. Atualize. Jogue.</h2><p>Contas e salas ficam no servidor central. O aplicativo só baixa o jogo quando houver uma nova versão.</p></div><ol><li>Baixe novamente o atualizador desta versão para habilitar o componente de voz. Abra-o e, ao terminar a instalação, clique em <strong>Jogar</strong>.</li><li>Crie sua conta ou entre com nome e senha. Compras e frota ficam salvas no servidor.</li><li>Escolha Battle Royale, Guerra, treino Offline, PvP Deserto ou Naval. No BR, a fila começa com uma pessoa e bots; a contagem é de <strong>30 segundos</strong>.</li><li>Todos os participantes precisam da mesma atualização para jogar juntos.</li></ol></section>
<footer>Servidor: <code>192.168.101.24</code>. O acesso exige estar na mesma rede ou ter uma rota/VPN até a VM. Não é necessário digitar IP ou porta no fluxo normal do jogo.</footer>
</main></body></html>''' % (
        escape(client['version_name']), escape(client['version_name']), escape(notes['date']),
        escape(notes['title']), escape(notes['summary']), escape(client['version_name']),
        int(client['version']), cards, versions)
