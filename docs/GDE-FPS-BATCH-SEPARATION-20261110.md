# Otimização C++ da separação de bots — 10/11/2026

## Objetivo e implementação

Extrair o cálculo de separação de personagens próximos, executado pelo diretor de bots da Guerra a cada física tick, do loop por vizinhos de GDScript para uma única chamada nativa da GDExtension C++.

Branch `ia/gde-fps-hotpath-20261110` derivada do piloto `70df12c` (poses nativas), independente de `main`. A separação nativa usa `--experimental-native-separation` e fica **desligada por padrão**. O fallback GDScript é preservado. `WarNativePoseMath.separation_batch(PackedVector3Array)` calcula repulsão horizontal de vizinhos a menos de 1,1 m para todos os atores elegíveis, usando uma passagem C++ por array. `WarBotDirector._prepare_native_separations()` recolhe jogadores vivos/deployados/fora de veículo e mapeia resultados por `peer_id`. A lógica de rotas, tiro, vida, colisões autoritativas, dano regional e `move_and_slide()` permanece no Godot/Jolt.

O caminho nativo de step/escadas (`--experimental-native-step`) foi testado **e rejeitado**, pois regressou no teste de FPS gráfico. Seu código, script/flag e teste foram retirados desta branch; os binários atuais contêm apenas o piloto de poses existente + separação. Não interpretar a equivalência da física como ganho de FPS.

## Testes de equivalência

- **20.600 verificações sem falha** em `tests/gde_native_separation_qa.gd`, 100 amostras por quantidade (0, 1, 2, 12, 28, 57), com grupos próximos/distantes, alturas variadas e posições quase coincidentes. Erro máximo de vetor de força ~8,43e-7.
- Windows x86_64 e Linux x86_64 compilaram bibliotecas **debug e release** contra godot-cpp / Godot 4.7.2. O algoritmo final limpo passou **20.600 verificações matemáticas** em Windows debug, Windows release isolado (manifest apontando à DLL release) e Linux debug/release. O teste Windows release precisou de `\.godot/extension_list.cfg` no projeto mínimo, pois executar sem import/catálogo de extensões não registra a classe. Não houve mudança no manifesto do jogo.
- **QA em cena real** `tests/gde_native_separation_runtime_qa.gd -- --experimental-native-separation`: 12 bots durante 60 ticks, **720/720 comparações**, com **90 amostras de força não zero** (dois pares aproximados artificialmente para QA). Força máxima divergente 2,98e-8 e 60/60 ticks com o caminho nativo ativado. Estado de separação amostrado no mesmo snapshot de cena após atualizar a grade espacial; esse teste não substitui multiplayer.

## Benchmark de FPS gráfico — GTX 1650 / 1080p / Forward+ / Médio a 100%

Fixture `tests/benchmark/war_1080p_benchmark.gd`, Favela com **28 bots** e medição de 14 s após 8 s de aquecimento. Ordem GDScript → C++ → C++ → GDScript. As quatro rodadas indicaram **100% dos frames com janela em foco**. Nenhuma alteração de Jolt ou configurações publicadas.

| Rodada | Caminho | FPS mediano | Frame P50 ms | Frame P95 ms | Frame P99 ms | Frames em foco |
|---|---|---:|---:|---:|---:|---:|
| 1 | GDScript | 36,73 | 27,222 | 36,741 | 47,202 | 519/519 |
| 1 | C++ separação | 39,88 | 25,078 | 35,866 | 41,879 | 545/545 |
| 2 | C++ separação | 36,77 | 27,195 | 45,057 | 61,745 | 503/503 |
| 2 | GDScript | 32,45 | 30,821 | 58,885 | 82,168 | 426/426 |

Relatórios completos com `gpu_ms`, `physics_ms`, `process_ms`, histogramas, horários, draw calls, compilação de pipelines e foco da janela em `docs/benchmark-results/gde-fps-separation-20261110/focused-*.json`.

**Leitura:** o C++ melhorou FPS mediano, P95 e P99 em ambos os pares. Há uma importante mudança de carga ao longo do tempo, inclusive aumento da média do tempo da GPU na R2, e outros Godots headless de agentes trabalhando simultaneamente no computador. Assim **não existe prova estatística de ganho permanente** ou autorização para habilitar por padrão. A tendência é positiva e justifica mais A/B isolado.

## Critérios de promoção

1. Comparar pelo menos três novos pares AB/BA com janela focada, processos paralelos de teste encerrados **pelos seus responsáveis**, temperatura/clock da GTX1650 estabilizados e mesmo cenário. Não matar processos de outras IAs.
2. Validar offline 12/28 bots e multiplayer cliente/servidor, escadas, veículos, colisões e tiro, com mesmo comportamento de separação.
3. Aprovar P95/P99 sem aumento de travadas no spawn ou erros nativos; revisar compatibilidade GDExtension em Windows/Linux exportados e o crash intermitente do editor na primeira importação já documentado no piloto anterior.
4. A rotina é autoritativa do `WarBotDirector`: pode melhorar FPS do **host/offline** e CPU do servidor, mas no **cliente remoto** sem bot authority o ganho direto de FPS não deve ser presumido.
5. Não fazer merge de `main` nem publicação do jogo antes da homologação. Flag continua opcional.
