from html.parser import HTMLParser
from pathlib import Path
import json, sys

root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'distribution'))
from release_notes import render_download_page, load_notes

notes=load_notes('1.9.7')
client={'release_notes':notes,'version_name':'1.9.7','version':69}
html=render_download_page(client)
class Parser(HTMLParser):
 def __init__(self): super().__init__();self.details=[];self.stack=[];self.sections=[];self.links=[]
 def handle_starttag(self,tag,attrs):
  a=dict(attrs)
  if tag=='details': self.details.append(a)
  if tag=='section': self.sections.append(a.get('id'))
  if tag=='a': self.links.append(a.get('href'))
parser=Parser();parser.feed(html)
history=json.loads((root/'distribution/release-history.json').read_text(encoding='utf8'))
prior=[item for item in history if item['version']!='1.9.7']
assert len(parser.details)==len(prior)+1+len(notes['changes'])
assert sum(1 for d in parser.details if d.get('class')=='version-entry' and 'open' in d)==1
assert 'historico' in parser.sections and '#historico' in parser.links
assert html.count('Adições</h3>')==len(prior)+1 and html.count('Correções</h3>')==len(prior)+1
assert '1.6.2' not in [item['version'] for item in history]
assert all(version in html for version in ('1.9.7','1.9.6','1.9.5','1.8.3','1.6.7','1.2.1'))
assert 'width=device-width' in html and '@media(max-width:540px)' in html
assert 'Javelin' in html and 'ToqueDeCampo.exe' in html
(root/'work/history196-preview.html').write_text(html,encoding='utf8')
print('PASS history:',len(prior),'prior versions,',len(notes['changes']),'expandable latest cards, both columns and mobile layout')
