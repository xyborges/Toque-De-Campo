# 1.9.5 — Combate em equipe

Publicada no Ubuntu em 27/10/2026, build 67. A 1.9.6 altera o requisito inicial de duas pessoas e acrescenta a Javelin.

- Guerra online: dois humanos em equipes opostas iniciam a partida; bots completam até seis por equipe e cedem a vaga para humanos, com reposição ao sair.
- Placar superior com objetivos por cor relativa à equipe e tickets no centro. Ao fim, tela de resultado durante 60 segundos e reinício da operação.
- Pontos capturados reabastecem a equipe que controla o local: infantaria junto à caixa e operador de blindado na área. O uso tem intervalo de 20 segundos.
- Tanques têm cortina de fumaça com intervalo de 45 segundos. Ela encobre a visão de mísseis TV dentro da nuvem, inclusive a térmica; não impede fisicamente um impacto.
- Médico equipa um kit com G e mantém o botão esquerdo pressionado para curar. Aliados à frente a até um metro têm prioridade; sem aliado próximo, o médico cura a si. O tratamento consome cargas.
- Atirador equipa binóculos com G, alterna o zoom com o botão direito e não dispara enquanto usa o equipamento.
- Operador do drone permanece no local, com arma guardada e controle nas mãos; velocidade aumentada em 15% e som mais alto durante movimento. A morte do operador interrompe o controle e o drone cai.
- Bots em blindados identificam veículos adiante, verificam espaço lateral e tentam ultrapassar ou param quando não há passagem.
- Grama do Guerra: 67.804 tufos na medição atual, com MultiMesh e LOD. Um teste de 45 s na GTX 1650, 18 participantes, 1954×1080, registrou média de 49,86 FPS e 1% low de 28,50 FPS. É uma execução isolada, não uma garantia de 60 FPS.

## Verificações locais

- `tests/run_bots195_network.py`: servidor e três clientes DTLS testaram equilíbrio, substituição e reposição de bots, sincronização de binóculos e fumaça e início de nova rodada.
- `tests/round195.gd`, `tests/support195.gd`, `tests/supplies_smoke195.gd` e `tests/drone_traffic195.gd`: regras de reinício, equipamentos, suprimentos, cortina e drone.
- `tests/smoke195_visual.gd`: câmera TV com fumaça e térmica, preservando HUD.
- `tests/near_miss195.gd`: mixer nativo confirmou som direcional para passagem de projéteis à esquerda e à direita.
- `tests/traffic_drive195.gd`: manobra física em pista controlada; a cobertura de rotas e tráfego reais do mapa ainda é limitada.
