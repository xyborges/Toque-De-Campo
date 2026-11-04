# 1.9.4 — Combate e ambientação

Publicada em 27/10/2026: versão 1.9.4, build 66; cliente e servidor atualizados juntos.

- Recarga da sniper: movimentos da arma e das duas mãos pelo tempo já replicado de recarga, em primeira e terceira pessoa. A luneta fecha quando a recarga começa. O modelo GLB é uma malha única: não há carregador ou ferrolho separado para animar individualmente. O tempo de recarga e as regras da munição continuam os mesmos.
- Mira deitada no Guerra: limite de 0,38 radianos para baixo, aplicado ao cliente e à autoridade. Ao levantar, a amplitude anterior é restaurada. O modelo não se adapta automaticamente à inclinação do solo.
- Fontes espaciais de armas, impactos e explosões usam separação estéreo mais pronunciada. O ouvinte acompanha a orientação da câmera. Não implica áudio binaural/HRTF.
- Guerra: 61.285 tufos de grama contra 53.237 no cenário de referência, preservando os filtros de implantação, lotes e LOD. 45 segundos de teste isolado com 18 participantes: média 48,51 FPS, 1% low 23,78, pior quadro 59,98 ms. A cena varia e a resolução registrada foi 1954 × 1080; não é comparação idêntica de carga com o ensaio de 75 segundos da 1.9.3.
- Ragdoll ao morrer: força limitada no tronco e no segmento atingido, na direção do impacto, com impulso maior para explosivos e atropelamento. A simulação permanece local como antes. Tiros posteriores em corpos não foram adicionados.
- Atropelamento por blindados no Guerra: contato efetivo no sentido de deslocamento, velocidade mínima 3 m/s e dano progressivo. O servidor valida operador, partida, ocupantes, velocidade e colisão; uma mesma vítima tem intervalo mínimo de um segundo. Fogo amigo usa a penalidade existente.

## Verificações

- `tests/sniper194.gd`: 24 verificações de poses, munição, pausa, luneta e limite de mira.
- `tests/stereo194.gd`: medição do mixer nativo confirma canais esquerdo/direito e inversão ao girar o ouvinte.
- `tests/run_sniper194_network.py`: dois clientes e servidor DTLS, com recarga real, observador e morte por atropelamento transmitida ao outro cliente. Houve avisos de fila UDP cheia no carregamento de um cliente; a sessão terminou com sucesso, mas não demonstra ausência de picos de rede.
- `tests/run_review192_transition.py`: 34 verificações da troca Deserto → Guerra, combate, limite de mira deitada no servidor e no observador, APC, Stinger e respawn.
- `tests/impact194.gd`: nove verificações, incluindo APC e tanque, contato lento real, autoria, fogo amigo e impulso limitado. `tests/ragdoll_contact_stress.gd`: 12 corpos em contato com paredes sem falhas.
- `tests/art188_reload.gd`: 56 verificações da recarga anterior de FAL e Glock sem falhas. Pacote exportado passou nas cinco verificações de proteção.


- Após publicação, o instalador HTTPS instalou a versão e não repetiu o download; duas contas no servidor Ubuntu completaram 21 verificações de combate e respawn.
