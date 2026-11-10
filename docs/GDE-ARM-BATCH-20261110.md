# GDExtension — braços e cotovelos em C++ (10/11/2026)

## Objetivo
Migrar o solver visual articulado `WarHumanRig.pose` (ombro, cotovelo, braço superior, antebraço e mão) para C++ e agrupar os **dois braços do mesmo personagem** em uma única chamada nativa quando a atualização normal de postura já conhece os dois alvos. Reduzir trabalho no GDScript **sem atualizar hitboxes fora de sincronia nem quebrar recarga, mira, ferimentos ou multiplayer**.

## Contexto Git e segurança
Branch `ia/gde-arm-batch-20261110`, worktree isolada derivada do piloto C++ `914d789`. A `main` e a versão publicada não devem ser alteradas até aprovação de testes reais. Flag experimental herdada `--pose-gde-pilot`; sem ela a versão original de GDScript permanece o padrão.

## Arquitetura aplicada
- `WarNativePoseMath.arm_batch()` recebe arrays compactos de ombro, alvo, basis da mão, basis do torso, lado, proporção e cuff; devolve por braço `[arm,upper,lower,hand]` (`Transform3D`). O cálculo inclui extensão proporcional, plano de dobra do cotovelo, quaternion dos ossos, punho, escalar do antebraço e orientação da mão.
- `WarHumanRig._prepare_arm` prepara dados e preserva a política de cache, modelos de mão e estados de recarga. `_solve_arm_gd` replica o cálculo original como referência/fallback. `_apply_arm` aplica as matrizes ao `Node3D` e mantém `grip_error` e cache.
- `WarHumanRig.pose_pair` resolve ambos os braços sincronamente por uma chamada nativa quando possível; chamadas individuais de arma/granada/moto recebem cálculo nativo de um braço, preservando fallback.
- `WarStance._refresh_grip_pose` e `GamePlayer._pose_weapon_arms` usam `_pose_arms_pair`; o override de `WarPlayer` mantém marcadores de armas importadas e transição de recarga.
- Membro incapacitado segue `_pose_arm` anterior, sem forçar IK ou gesto novo.
- `WarCollisionPoseSolver` (poses autoritativas de colisão P1k) **não é substituído**: sua independência é intencional até demonstrar equivalência física em testes de rede.

## Limites
Este lote é de **dois braços por personagem**, e não uma chamada para 28 personagens. Não deve ser anunciado como a mesma aceleração de 4,17x que o microbenchmark anterior mediu para uma transformação simples de torso com 28 entradas. O benefício deve ser medido com o solver completo, incluindo a criação de arrays e consumo de resultados.

## Testes exigidos antes de `main`
- Paridade pura `tests/gde_arm_batch_qa.gd`: 480 pares de cotovelos aleatórios contra fallback original, tolerância máxima 2.5e-4.
- Paridade end-to-end `tests/gde_arm_runtime_qa.gd`: WarPlayer real, 5 armas, variações de pitch/lean/prone, braços, antebraços, mãos e hitboxes.
- Benchmark do IK completo `tests/gde_arm_batch_benchmark.gd`: 28 atores, 2 braços por ator, 360 quadros, 7 repetições alternadas, comparando cálculo GDScript e lote C++.
- Regressões `tests/pose189_validation.gd`, `tests/prone_weapon_pose_validation.gd`, P1k/servidor, QA multiplayer.
- Comparar 0/12/28 bots e gameplay 1080p GTX 1650 sem outros Godots concorrendo; calcular P95/P99 e verificar resposta a tiro.

## Disponibilidade binária
Windows x64 e Linux x64 precisam de binários debug/release correspondentes aos novos símbolos. O build Linux em WSL Ubuntu 26.04 já demonstrou compatibilidade de execução do piloto anterior, mas o binário novo e o sistema alvo do servidor ainda devem ser testados, sobretudo dependências GLIBC. Não publicar binários sem paridade.

## Segunda arquitetura: aplicação direta em C++ (mesmo dia)
O primeiro microbenchmark de IK completo confirmou que calcular em C++ e **retornar quatro `Transform3D` por braço para o GDScript aplicar** era pior: 28 personagens × 2 braços × 360 frames × 7 rodadas, GDScript **72,943 ms** vs C++ com retorno de arrays **97,334 ms** (o C++ era ~33% mais lento). O 4,17× do piloto anterior se referia a matemática simples de tronco, não ao IK completo.

Foi criada a API `WarNativePoseMath.apply_arms_direct(Array inputs) -> int`. A biblioteca recebe os alvos calculados pelas regras de armas em GDScript, os nós já existentes (`arm`, `upper`, `lower`, `hand`) e os dados de pose. Resolve o IK **e escreve nativamente no `Node3D`**: braço basis, upper position/scale, antebraço transform, mão transform. Não retorna as quatro matrizes e não aloca um Array de Transform3D no caminho normal. `WarHumanRig._finish_arm` mantém no GDScript apenas material/luva, `grip_error`, cache e regras de recarga/arma. Se a classe não estiver carregada ou a chamada retornar quantidade inválida, o solver GDScript permanece como fallback.

### Verificações efetivamente executadas
- `tests/gde_arm_batch_qa.gd`: **5.282/5.282**, 480 pares aleatórios contra referência GDScript, erro máximo 4,44e-6 (equações C++ completas).
- `tests/gde_arm_runtime_qa.gd`: **2.700/2.700**, cinco armas, 150 estados, 300 braços aplicados diretamente pelo C++ em 150 chamadas (uma para cada dupla), incluindo transformações `Area3D` de hitboxes montadas nas partes. Erro máximo 1,14e-5. Avisos de UIDs de importação resolvidos por caminho; sem `SCRIPT ERROR` de IK.
- Teste de carga **isolado do cálculo+escrita de nós**: `tests/gde_arm_direct_benchmark.gd`, 28 personagens × 2 braços × 360 frames, 7 rodadas alternadas. GDScript resolve+aplica **125,078 ms** mediana, C++ nativo resolve+aplica **89,275 ms**, velocidade **1,401×** (economia de ~28,6% no cálculo e nas escritas dos nós). Dados de alvos pré-preparados; NÃO é FPS real nem inclui regras de arma, render ou Jolt.
- `tests/gde_pose_platform_smoke.gd`: Windows Godot 4.7.2 **PASS** após recompilar DLL; Linux Godot 4.7.2 com `.so` nova **PASS** (duas escritas nativas de braço, cálculos válidos). DLLs debug/release Windows e SOs debug/release Linux compiladas.
- **Servidor dedicado/headless:** teste 28 bots A/B em dois pares está sendo executado. Seu resultado só suporta alegações headless se concluído e sem concorrência; não extrapolar para FPS cliente 1080p GTX 1650.

### Segurança e limites
- Flag `--pose-gde-pilot` requerida; `main` e builds de produção não alteradas.
- `WarCollisionPoseSolver` de hitboxes autoritativas não é redirecionado para o C++ por enquanto; a nova API modifica nós visuais compartilhados, cujos filhos de hit region acompanham os transform.
- GDExtension *pode* acessar nós nativamente, mas o código de decisão/arma e material permanece GDScript para evitar reescrever sistemas que dependem de rede, recarga e metadados do jogo.
- O ganho de **1,401×** é na rotina específica, medido com objetos `Node3D` simples. Não significa 40% de FPS.
- A execução inicial do editor/import com a extensão anterior havia encerrado anormalmente uma vez, sem reprodução consistente. Esse gate de estabilidade do editor não está formalmente encerrado.

## Pares reais 28 bots no servidor headless (Godot 4.7.2)
Quatro execuções sequenciais, mesma revisão, n=~1.350–1.430 frames coletados cada. A/B em ordem **C++ → GD → GD → C++**. Os relatórios individuais estão em `docs/benchmark-results/gde-arm-direct-20261110/28bots-*.json`, extraídos dos eventos `WAR_LAG_LOAD_RESULT` dos logs. Todos declararam **`failures: []`**.

| Rodada | Caminho | Frame P50 (ms) | Frame P95 (ms) | Física P95 (ms) |
|---|---|---:|---:|---:|
| R1 | C++ direto | 15,023 | 32,603 | 34,664 |
| R1 | GDScript | 14,310 | 31,801 | 38,749 |
| R2 | GDScript | 14,794 | 32,992 | 31,055 |
| R2 | C++ direto | 14,043 | 31,262 | 22,848 |

**Veredito:** sem aceleração consistente do tempo total de frame; C++ pior na primeira rodada e melhor na segunda. A física P95 variou muito, embora a extensão não modifique o Jolt. Há outros Godots de QA de Favela executando no mesmo desktop. São medições **headless**: não comprovam FPS na GTX1650 em 1080p nem custo de render/pose visual no client. P99 não foi coletado pelo `war_lag_load.gd` e não deve ser inventado. A redução de 28,6% no microbenchmark do IK+Node3D (125,078 vs 89,275 ms para 20.160 braços) continua válida somente para essa rotina.

### Regressões adicionais
- `tests/prone_weapon_pose_validation.gd -- --pose-gde-pilot`: **1.126 checks / 0 failures**, incluindo pronto, ferro/óptica ADS, mira/recarga de FAL/AK/Glock/sniper e transições de postura em cena.

- `tests/pose189_validation.gd -- --pose-gde-pilot`: **2.196 checks / 0 failures**, menor elipse de folga da arma/torso 1,08442777 (aprovada), contato das mãos com as armas, penetração dos braços, região física da cabeça, inclinação e ADS. O teste reescreve `tests/pose189-validation-results.json`; o arquivo gerado foi restaurado ao conteúdo original de HEAD após registrar os resultados, sem mudança desse snapshot no commit.

## Gate de distribuição e editor (última revisão)
- Godot 4.7.2 Windows **debug e release**: método nativo `apply_arms_direct` executado em runtime; teste mínimo `direct_arm_writes=2, ok=true`.
- Godot 4.7.2 Linux **debug e release**: mesmo teste mínimo passou com `direct_arm_writes=2`.
- **Import do editor Windows:** ao importar pela primeira vez um projeto mínimo que contém a extensão de release, Godot retornou código `-1073741819` (`0xc0000005`). O Event Viewer registrou falha no módulo executável Godot. A versão mínima **sem extensão** passou 3/3 importações; depois de criada a cache, o projeto mínimo COM extensão também passou **3/3** encerramentos seguintes. Não se determinou a causa raiz; há histórico semelhante no piloto anterior. Não declarar editor completamente homologado e **não tornar padrão em main** até investigar carga inicial em instalação limpa e completar QA cliente multiplayer.
- A branch preserva flag `--pose-gde-pilot` e fallback. Merge ou release dependem de testes de FPS e gameplay no cliente GTX1650 e eliminação do risco de crash na importação inicial.
