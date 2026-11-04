# P0b — baseline de combate, hitbox e câmeras FPP/TPP

**Emissão:** 04/11/2026  
**Projeto:** Toque de Campo 1.13.1 — Godot 4.7.2 — GL Compatibility/GTX 1650  
**Estado:** fixtures/testes criados e executados; **SEM alterações de runtime/gameplay, SEM publicação**.  
**Base:** [revisão P0](FPP-TPP-REVISAO-P0-20261104.md) e [plano FPP/TPP](FPP-TPP-CORPO-UNICO-PLANO-20261104.md).

## 1. G3 — quinas, parede, janela e mira da câmera

Novo teste `tests/true_fpp_p0_cover_baseline.gd` usa a fixture real `WarGame`, cria `StaticBody3D` de geometria controlada com colisão, dispara pelo servidor atual com G3 em *hip FPP* e *hip TPP*, e captura `shot_packet`, origem de câmera, `shot_blocked`, raycast de seleção do alvo, eye->muzzle e raycast retilíneo de diagnóstico do projétil. **Não alterou `_server_accept_shot`.**

**Resultado:** seis cenários, 12 disparos aceitos pelo servidor, teste instrumental saiu com exit 0. Isso significa que **a fixture funcionou**, não que a paridade foi aprovada.

| Caso | Raio FPP encontra | Raio TPP encontra | Bloqueio `shot_packet` | Observação |
|---|---|---|---|---|
| Campo aberto | nada | nada | falso / falso | sem cover intencional |
| Parede entre olho e cano | parede | — | verdadeiro / verdadeiro | proteção eye->muzzle funcionou |
| Quina direita | nada | quina | falso / falso | **diferença de alvo e trajetória**; raio retilíneo do cano encontra parede no TPP |
| Quina esquerda | nada | nada | falso / falso | caso sem diferença detectada |
| Janela com colunas/lintel/peitoril | nada | coluna direita | falso / falso | **diferença de alvo e trajetória**; raio retilíneo do cano encontra parede no TPP |
| Muro baixo | nada | nada | falso / falso | caso sem diferença detectada |

**Atenção:** `shot_blocked` na implementação atual representa principalmente a *varredura olho→cano*, não um relatório de todas as barreiras na trajetória balística. A coluna `straight_line_hit` é diagnóstico por raycast, **não** resultado final da simulação de projéteis com gravidade e arrasto. A P1 deverá comparar também impacto/dano reais.

Relatório estruturado: `work/fpp-tpp-p0-20261104/g3-cover-baseline.json`.

## 2. Capturas gráficas com câmera efetiva

Novo teste `tests/true_fpp_p0_visual_baseline.gd` na GTX 1650, 1280×720, Compatibility, com quarto retangular/cobertura simples:

| Captura | Preferência | Câmera efetiva | Draw calls de um quadro |
|---|---|---|---:|
| `fpp_hip.png` | FPP | FPP | 67 |
| `tpp_hip.png` | TPP | TPP | 102 |
| `fpp_ads.png` | FPP | FPP | 67 |
| `tpp_preference_ads.png` | TPP | **FPP** | 67 |

As quatro imagens foram salvas com código `OK (0)`; mostram o G3 e mãos de apresentação na FPP, e corpo/arma reais na TPP. A mudança TPP→ADS transforma a câmera **efetiva** em FPP; por isso medir paridade durante ADS sem registrar a câmera real é inválido.

São *amostras de draw calls em fixture simples*, **não** um benchmark completo de FPS, GPU, 28 bots ou multiplayer.
Arquivos: `work/fpp-tpp-p0-20261104/{fpp_hip,tpp_hip,fpp_ads,tpp_preference_ads}.png` e `visual-baseline.json`.

## 3. LOD e colisões por membro: risco demonstrado

Novo `tests/true_fpp_p0_hitbox_lod_baseline.gd` cria um ator remoto novo para cada distância de observador (10/70/150/300/1700 m). Em 1.700 m, observador é colocado a -1600 m e ator a 100 m na fixture para não acionar a condição de água fora do mapa.

Foi imposto atraso de apresentação para simular o ramo `now < next_pose_usec` da `WarPlayer._animate_walk()`, **enquanto o estado `WarStance.advance` segue atualizando**:
- Agendamentos observados após atualização: ~33 ms em 10–70 m, ~66 ms em 150 m e ~125 ms em 300–1700 m (aproximadamente 30/15/8 Hz).
- Transição de *standing* para *prone*, com todos os pesos de postura assentados e a pose visual suspensa: maior diferença **1,621 m** entre ponto antigo de região e ponto recalculado.
- Transição parcial de seis ticks físicos (100 ms), com pose visual suspensa: diferença máxima **1,025 m** no teste.
- As cinco distâncias reproduziram o desvio sob a mesma supressão forçada da pose; **não é uma medição de frequência de falhas em partida real**.

**Interpretação:** `Area3D` físicas são filhas de nós de apresentação. Suspender seu ancestral enquanto a postura progride pode deixar acertos visual/fisicamente desatualizados. Não extrapolar 1,025 m para o movimento normal dos players: a fixture deliberadamente forçou o agendamento de omissão. Implementar `CollisionPose` em tick físico (inclusive headless/listen host) e `PresentationPose` com LOD visual independente, e então repetir a medição sem forçar `next_pose_usec`.

Relatório: `work/fpp-tpp-p0-20261104/hitbox-lod-baseline.json`.

## 4. Baselines da P0a preservadas

- `tests/true_fpp_p0_g3_baseline.gd`: 3 vistas, disparos G3 aceitos FPP/TPP, FPP copy 0,264 m do cano físico no caso hip, ADS força FPP, `ChargingHandle` não movimentado.
- `tests/scoped_muzzle_regression.gd`: **vermelho**, 326 de 490 verificações falharam (FAL/AK, 0,593 m erro máximo). Não corrigir teste apagando `view_root` até haver migração da óptica.
- `tests/optics_universal_validation_20261103.gd`: verde 242/242 **headless**.
- `tests/prone_weapon_pose_validation.gd`: verde 1126/1126 **headless**.

## 5. Regressões antigas adicionais — não aprovadas nesta rodada

- `tests/camera_collision.gd` executado headless: **erro de fixture em linha 20**, `game.local_player` nulo ao posicionar o ator. Interrompido após erro; não gerou resultado útil para a mecânica FPP/TPP.
- `tests/war_locomotion_network.gd` executado isoladamente: **inconclusivo**, porque este teste requer três processos (autoridade ENet, mover e observador). Sem os dois clientes, o servidor expirou aguardando peers; houve também aviso de arquivo X509 TLS da fixture indisponível. Não confundir timeout de orquestração com falha de locomoção do game.
- `tests/pose189_network.gd` herda outro fixture multiprocesso, também iniciado isoladamente por engano; execução interrompida. Não atribuir o resultado à rede do jogo.
- Saídas dos comandos em `work/fpp-tpp-p0-20261104/regression-*.log`. Para repetir, primeiro localizar o orquestrador que inicia todas as partes, reservar porta e validar os certificados/configuração. Não executar os scripts de rede como testes unitários independentes.

## 6. Próximo gate — P1a (ainda NÃO implementado)

1. `CollisionPose` em física de 60 Hz para *head, chest, arm, leg*, mesmo com câmera longe ou sem câmera. Preservar `Area3D`, `muzzle`, dano e eventos do servidor.
2. `PresentationPose` em LOD de distância somente para meshes/FX, sem congelar ancestrais das hitboxes. Separação mínima e reversível, sem refatorar tudo para `Skeleton3D`.
3. `LogicalAimOrigin` / `LogicalAimDirection` serão prototipados em testes sob flag própria, **sem alterar a regra atual de tiro** até a avaliação anti-cheat/cobertura.
4. Depois de P1a, piloto G3 irons + câmera real, depois ópticas PiP (etapas P2a/P3a/P2b/P4). Não remover duplicata FPP antes do gate PiP.
5. Instrumentar impacto/dano real do projétil, jitter online com dois processos independentes, e repetir os cenários em listen server e dedicated.
6. Benchmark com 28 bots em 1080p, FPS mediano/p95/p99 e largura de banda; não confundir draw calls da fixture com o desempenho de produção.

### Pendências e integridade
- Rede de **duas máquinas reais** e comparação de frame times com 28 bots não foram executadas nesta etapa.
- Navegação do Afegão continua separada e desatualizada; **não** regenerar mapas neste projeto de câmera.
- Não alterar loot, spawns BR, scripts de armas, colisão, `main.gd`, `player.gd`, `reload_pose.gd` nem áudio enquanto os testes compartilham o projeto com outras sessões.
- O plano principal e revisão P0 ficam vinculados a este relatório. Não declarar P0 completamente aprovada enquanto os testes de rede/desempenho estiverem pendentes.
