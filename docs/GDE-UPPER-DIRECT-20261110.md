# C++ direto: tronco, cabeça, quadril e ombros — 10/11/2026

## Objetivo
Reduzir trabalho repetido por avatar no cliente e host, sem decimar animação, consulta a colisões nem o rig físico. O Godot/Jolt já faz as chamadas de física em C++; o piloto anterior de movimento de degraus em C++ piorou P95 e permanece rejeitado. O WarPlayer já aplica um LOD por distância em `_animate_walk` de avatares remotos; aumentar a decimação da pose no servidor poderia deixar hitboxes obsoletas. Assim, esta etapa foca **reduzir o custo do mesmo tick**, não pular ticks.

Branch `ia/gde-upper-direct-20261110`, derivada da branch com C++ padrão `ff6b2b3` (não foi integrada à `main`).

## Implementação
`WarNativePoseMath.apply_upper_direct(parts, pelvis, rest, pitch, lean, torso_scale, head_scale, articulated)`: calcula e aplica, em uma única chamada GDExtension C++, os mesmos sete pivôs do `GameInfantryPose.apply` de referência: pelvis, duas pernas, torso, cabeça e dois ombros. Usa `WarNativePoseMath.upper_transform` nativo preexistente e preserva, sem alterar, a ordem de transformações do quadril, giro de pernas, animação do tronco, pescoço, escalas e largura do colete. As partes `Area3D` das hitboxes continuam sendo filhas dos mesmos nós, e as transformações de seus pais atualizam no mesmo tick.

Antes de escrever, a biblioteca nativa verifica a existência dos seis nós de corpo e todas as entradas do cache de pose. Se não houver biblioteca, o novo método não estiver disponível, algum nó faltar, a pose estiver desabilitada ou o método retornar falso, `scripts/infantry_pose.gd` usa o GDScript anterior integralmente. `--war-upper-legacy` força apenas esse caminho de tronco GDScript para comparativo A/B, mantendo as rotinas nativas anteriores de armas e separação de bots.

Não altera servidor, rede, física, colisões, dano, FPP/TPP, pontaria, regras nem material.

## Validação de equivalência
`tests/gde_upper_direct_qa.gd` usa um `WarPlayer` real em `war_optics_fixture.gd`; **375 combinações** de FAL/G3/Glock/AK/sniper, pitch, lean e proporções de tronco/cabeça, comparando pivôs e todas regiões regionais de acerto; **17.250 verificações sem falha**, erro máximo observado ~**1,33 × 10⁻⁷** unidades. A biblioteca compilou em Windows x86_64 e Linux x86_64, debug/release.

O benchmark isolado alternado de 5 rodadas × 800 atualizações por caminho resultou em GDScript mediana **17,262 ms** e C++ mediana **15,044 ms** (C++ **1,147×** mais rápido, ou cerca de **12,9% menos tempo** nesta rotina). Não representa ganho de FPS global.

## Critérios de promoção
- 28 bots no cliente gráfico GTX 1650 1080p Forward+ Médio 100%, duas rodadas AB/BA, janela 100% focada, P50/P95/P99 e GPU/física.
- Smoke Windows + Linux, build de importação, QA de posturas/armas e 28 bots headless.
- Multijogador real com clientes e servidor Linux; revisar crash intermitente na primeira importação de plugin nativo de piloto anterior.
- Não mexer em `main` nem publicar versão até homologação; documentar regressões ao invés de ativar automaticamente caso o benchmark gráfico piore.

## Benchmark gráfico da Favela: não promover como padrão

Quatro execuções ordenadas **GDScript → C++ → C++ → GDScript**, cada uma com 28 bots ativos, Forward+ 1080p, perfil Médio/100%, 6 segundos de aquecimento e 12 segundos de medição, **100% dos frames com foco**. A/B testa **somente a nova aplicação direta do tronco**: as otimizações nativas anteriores de braços e separação permanecem ligadas em ambos os lados.

| Rodada | Aplicação do tronco | FPS mediano | P50 ms | P95 ms | P99 ms | Foco |
|---|---|---:|---:|---:|---:|---:|
| R1 | GDScript original | 46,40 | 21,550 | 38,836 | 56,806 | 485/485 |
| R1 | C++ novo | 45,91 | 21,782 | 35,204 | 73,880 | 483/483 |
| R2 | C++ novo | 34,84 | 28,704 | 40,069 | 58,075 | 416/416 |
| R2 | GDScript original | 51,22 | 19,524 | 31,493 | 46,750 | 542/542 |

Dados completos preservados em `docs/benchmark-results/gde-upper-direct-20261110/visual-*.json` (incluindo traço de frame, GPU/física, compilação de pipelines e foco). Outros testes de IAs ainda executam processos Godot em paralelo; é importante não atribuir toda a variação ao C++. Porém, a rotina **não apresentou vantagem consistente e regressou fortemente no R2**, portanto a ativação por padrão fica rejeitada nesta etapa.

**Política segura implementada após o A/B:** `GameInfantryPose.native_upper_direct_enabled` começa **false** e somente passa a true com `--experimental-native-upper`, desde que não esteja presente `--war-upper-legacy` e a GDE tenha a classe/método esperados. Sem isso o GDScript antigo continua atualizando a pose em todos os ticks. A política geral de C++ existente (`GameNativeRuntime`) para cálculo de IK dos braços e separação entre bots **não foi revertida**.

## Smoke final de plataforma
- Windows x64 debug: **72/72**, erro máximo 0.
- Windows x64 release: **72/72**, erro máximo 0, manifesto isolado apontando à DLL release.
- Linux x64 debug: **72/72**, erro máximo 0, Godot oficial 4.7.2.
- Linux x64 release: **72/72**, erro máximo 0, Godot oficial 4.7.2.

**Veredito:** código e testes da migração prontos para piloto, mas **sem merge na `main` e sem release**. O resultado confirma que portar setters/transformações nativas simples não elimina os custos maiores do frame; próximo investimento deve priorizar consultas de física redundantes, volume de corpos/collision shapes, render LOD que preserve hitboxes, e trabalho de instanciação na Favela, com profiling do cliente e servidor.
