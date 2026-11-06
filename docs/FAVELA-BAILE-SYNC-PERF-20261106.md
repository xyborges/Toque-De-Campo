# Favela — sincronizacao de seis musicas e benchmark do baile (06/11/2026)

## Correcao implementada
- Seis MP3s existentes preservados, sem gerar nem alterar faixas.
- Primeira musica inicia no inicio da operacao; ordem embaralhada deterministica sem repeticao imediata entre ciclos.
- Semente (`weather_seed`) e tempo (`war_clock`) recebidos nos snapshots ja existentes de `WarGame`; nao ha RPC extra, nem som no servidor dedicado. O cliente espera a semente do servidor.
- O mesmo estado determina musica e deslocamento tanto para jogadores ja presentes quanto para conexoes tardias; monitoramento a cada 0,2 s corrige deriva superior a 0,4 s.
- Audio 3D localizado no paredao, com corte real de playback acima de 100 m e retomada no offset atual ao retornar.
- Defeito real corrigido: `WarFavelaBaile` era `Node` e o `AudioStreamPlayer3D` ignorava a transformacao do campo, emitindo perto da origem do mapa. Mudou para `Node3D`, propagando o transform global do palco ao emissor.
- Na Favela real, o palco em (430, 121, -275) tinha emissor incorreto em (-39, 3, 0). Apos correcao, emissor em (391, 124, -275).

## Testes executados — Godot 4.7.2
- `tests/favela_baile_sync_qa.gd`: 102/102 PASS, incluindo seis arquivos, offsets, embaralhamento, limite 100 m, retorno, translocacao mundial e fonte 3D.
- `tests/favela_baile_qa.gd`: 120/120 PASS, 104 StaticBody3D.
- `tests/favela_runtime_qa.gd`: 37/37 PASS, oito veiculos sem sobreposicao.
- GDScript check-only: PASS; `git diff --check`: PASS.
- Cena isolada, Windows, Forward+ GTX 1650, V-Sync desativado, 1280x720, 200 quadros por passe: aproximadamente 1015 a 1131 FPS. Os seis projetores e quatro fachos tiveram custo baixo isoladamente (~0,02 a 0,10 ms no frame medio, com variabilidade).
- Favela completa, Windows, Forward+ GTX 1650, 1920x1080, 180 quadros por passe, sem bots nem HUD: aproximadamente 199 a 273 FPS nos passes A/B; custo das luzes nao e conclusivo devido a variacao entre passes. Nao extrapolar para 28 bots.
- Mixer nativo na cena isolada com palco deslocado para coordenadas reais: fonte tocando, pico observado ~-30 dB.
- No teste sintetico da Favela inteira, o stream estava tocando, com offset avancando e fonte a 59,2 m do ouvinte, porem o medidor de pico mostrou ~-200 dB inclusive a 3 m, 30 m, 60 m e 90 m. Com 110 m, o playback foi corretamente interrompido. Acrescentar AudioListener3D nao alterou este resultado.

## Limites e pendencias
- A divergencia do medidor no mapa completo impede afirmar audibilidade comprovada em partida real. Precisamos auditar o audio routing do mundo completo e ouvir/medir um cliente em sessao de jogo antes de integrar.
- Nao houve sessao multiplayer com dois clientes reais; sincronismo foi validado por contrato deterministico sobre relogio e semente do snapshot. Confirmar com dois clientes e entrada tardia em QA de rede.
- Comparativo de FPS nao inclui bots, gravacao de gameplay nem hardware alternativo; medir A/B com 28 bots para aprovar performance.
- Verificar licenca de redistribuicao dos seis MP3 antes de publicar.
- Sem merge em main, push remoto ou publicacao.
