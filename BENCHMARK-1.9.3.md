# Benchmark 1.9.3 — Guerra offline

27/10/2026. NVIDIA GeForce GTX 1650; Intel Core i5-11400H; Godot 4.7.2; Compatibility; viewport 1920 × 1080; VSync desativado. Um cliente nativo executando a autoridade offline e 17 bots. Não são 18 computadores nem uma medição da rede de produção.

## Comparação do backend de física

Mesma revisão de scripts e modelos, câmera estacionária observando a frente central, semente inicial 193, 18 participantes, 4.429 árvores e 53.237 tufos de grama. Cada execução dura 75 segundos, descartando os três primeiros. Inclui deslocamento, blindados e combate espontâneo. Não é uma reprodução determinística: decisões, disparos e objetos visíveis variam com os quadros e o andamento da batalha.

| Medição | Godot Physics | Jolt |
| --- | ---: | ---: |
| FPS médio | 25,30 | 51,01 |
| 1% low | 5,98 | 25,27 |
| Tempo médio por quadro | 39,53 ms | 19,60 ms |
| P95 por quadro | 93,77 ms | 24,79 ms |
| Pior quadro | 190,32 ms | 61,03 ms |
| Tempo GPU médio medido | 10,24 ms | 6,78 ms |
| Indicador de física médio | 12,25 ms | 7,79 ms |
| Máximo de draw calls observado | 1.515 | 1.545 |
| Disparos aceitos dos bots | 162 | 292 |
| Rejeições de disparo dos bots | 0 | 0 |

Os tempos dos monitores de processamento incluem trabalho e sincronização do motor; não devem ser somados como custos exclusivos. A melhora de tempo GPU também não demonstra que trocar o backend tornou o mesmo desenho intrinsecamente mais rápido: o estado da batalha, a carga do processador e a alimentação do renderizador diferem entre execuções.

Dados: `work/control193-final-offline.json` e `work/physics193/work/jolt193-final-offline.json`. Execução: `tests/offline193_benchmark.gd -- --label=NOME --seconds=75`.

## Diagnóstico anterior

O Profiler nativo (`work/offline193-profile.json`) destacou consultas de movimento dos blindados, deslocamento dos personagens e atualização das poses. Os temporizadores de diagnóstico registraram aproximadamente 2,26 ms por chamada a `vehicle.move_and_slide` numa execução Godot Physics. Esse ensaio instrumentado não é o benchmark final.

Foi reduzida a atualização de poses remotas por distância; eliminadas escritas redundantes de posição; conservado apoio validado de cascos parados; ampliados os setores visuais da grama e desativadas suas pequenas sombras. O mapa tático deixa de recriar a textura de território a cada alteração de porcentagem da captura.

## Integridade da jogabilidade

- 353 verificações de mobilidade mantêm seus limites de penetração, velocidade e travessia, sem relaxar as exigências para o Jolt.
- Recuperação parcial de sobreposição do Jolt produziu contatos residuais de até 5,9 cm nos primeiros testes. Recuperação completa eliminou as falhas desses cenários. O projeto conserva gravidade, velocidade de veículos e colisões de cobertura.
- Partida funcional em tempo real de 160 segundos: nove contra nove, oito bots embarcados, veículos em deslocamento, capturas, 819 disparos aceitos, 37 recargas e 14 mortes. Nenhuma rejeição de tiro nesse ensaio.
- Dois clientes reais com DTLS: 32 verificações de transição entre modos, disparos, recargas, postura replicada, Stinger, morte deitado e implantação passaram.

## Limites

51 FPS médios e 1% low de 25 FPS ainda não representam 60 FPS estáveis. Existe margem de otimização no desenho e na simulação. A comparação é uma execução de cada backend, no hardware deste PC, e não certifica todas as configurações, cenas e condições de rede. Não foram usados presets que removem vegetação de cobertura para aumentar o desempenho.
