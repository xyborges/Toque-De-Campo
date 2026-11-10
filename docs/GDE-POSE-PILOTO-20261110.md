# Piloto GDExtension de poses — 10/11/2026

## Hipótese e diagnóstico
- O LOD anterior de tomada de decisões reduziu chamados `_think` distantes, mas a física de `CharacterBody3D`, Jolt, colisões, criação de hitboxes e visuais permaneceram iguais. O limite compartilhado já era 40 decisões/s; a própria seleção adicional faz consultas de distâncias.
- Em dois pares headless de 28 bots do LOD anterior, os P95 de frame ficaram muito próximos: 31.88/30.60 ms e 30.95/30.67 ms (novo/antigo). O pico de P95 física no primeiro par não se repetiu no segundo. Não existe prova de ganho consistente.
- C++ pode acelerar matemática pura, mas não resolve automaticamente `move_and_slide()`, Jolt, renderização ou tráfego de rede. O custo total inclui a travessia GDScript↔C++, e usar muitas chamadas pequenas pode ser contraproducente.

## Escopo piloto
Implementação em worktree exclusiva `ia/gde-pose-pilot-20261110`, base `main` local `85cc9d1`.
Classe `WarNativePoseMath` em C++ via godot-cpp 4.7, Windows x64: `upper_transform`, `weapon_transform` e `upper_batch`.
Nenhum método nativo altera cena, estado de ator, hitbox, solver de física, RNG, autoridade, locomotor ou rede. É um cálculo puro sem efeitos colaterais. O GDScript original permanece a referência.

## Validação e decisão
- Compilar binário(s), importar GDExtension e validar classe na Godot 4.7.2.
- Executar `tests/gde_pose_parity_qa.gd`: contra funções existentes `GameInfantryPose.upper_transform` e `weapon_pose`, 900 estados aleatórios e lote de 28.
- Executar `tests/gde_pose_microbench.gd`: 7 repetições alternadas GDScript vs chamada nativa vs lote de 28. Medir duração total incluindo retorno de valores.
- Se o ganho local for pequeno, não substituir código de produção; buscar funções de pose maiores ou reuso de transformações. Se for expressivo, só então testar 28 bots reais, gráficos e paridade de hitboxes.
- Manter `main` e build publicada intocadas; somente branch experimental. Disponibilidade de compilador Linux e distribuição de .so é gate obrigatório.

## Resultados efetivamente medidos no JJ7U3G3 (Godot 4.7.2)

### Equivalência das transformações
- DLL Windows x64 de desenvolvimento compilada com MSVC e `godot-cpp` API 4.7.
- `gde_pose_parity_qa.gd`: **1.830/1.830 PASS** em 900 entradas de postura/arma e lote de 28. Erro máximo de tronco 7,03e-8; arma 4,92e-7 (diferença numérica tolerável).
- `gde_pose_runtime_qa.gd`: **842/842 PASS** sem flag e **842/842 PASS** com `--pose-gde-pilot`. Execução real das funções do script `GameInfantryPose`, com fallback íntegro e máximo de erro ~4,78e-7.
- Ativação no jogo é **somente por `--pose-gde-pilot`**. Em condições normais o código usa GDScript e a extensão não é invocada. Nenhuma mudança no Jolt, colisões, hitboxes, dano, IA, rede ou cálculo de ragdolls.

### Microbenchmark de matemática isolada (não é FPS)
Medições medianas de 7 rodadas alternadas com 28 bots × 1.200 frames = 33.600 transformações por rodada:

| Caminho | Mediana total | Aceleração da função |
|---|---:|---:|
| GDScript puro | 25,943 ms | 1× |
| C++ chamada individual | 15,478 ms | 1,68× |
| C++ em lote de 28 | 6,221 ms | 4,17× |

O processamento em lote mostra potencial, mas **a integração atual no `GameInfantryPose` usa o caminho escalar**, não o lote. Para usar o lote, seria necessário reunir estados de vários atores, sincronizar as fases de pose e medir custos de coleta/aplicação; isso ainda não foi implementado.

### Carga headless de 28 bots na Guerra (duas ordens A/B)
| Rodada | Ordem | Modo | P50 frame ms | P95 frame ms | P95 física ms | Falhas |
|---|---|---|---:|---:|---:|---:|
| R1 | primeiro | GDScript | 14,100 | 31,755 | 28,780 | 0 |
| R1 | segundo | C++ opt-in | 14,155 | 31,481 | 21,245 | 0 |
| R2 | primeiro | C++ opt-in | 14,594 | 31,965 | 29,881 | 0 |
| R2 | segundo | GDScript | 14,209 | 31,115 | 32,139 | 0 |

**Conclusão:** sem ganho consistente no P95 de frame; variação de física não decorre necessariamente do código C++, pois a extensão apenas calcula transformações. Cada execução utiliza a mesma carga e coleta aproximadamente 24 s, mas estas são simulações headless, sem testes de renderização na GTX 1650 ou multiplayer.

### Restrições de integração
- **Não alterar a `main` nem lançar atualização.** Este piloto está isolado na branch `ia/gde-pose-pilot-20261110`.
- Binário Linux para o servidor dedicado **ainda ausente**. WSL Ubuntu 26.04 tem SCons, mas não tem `g++/clang++` disponível e `sudo -n` não autoriza instalar compilador; não alegar paridade no Linux. Não instalar pacotes do usuário sem necessidade.
- A primeira inicialização `--headless --editor --import --quit` concluiu importação mas retornou `0xc0000005` na saída do editor. O Windows registrou exceção no processo Godot, sem atribuição comprovada à DLL. Execuções de testes com `--headless --script` passaram. O crash na saída do editor deve ser investigado antes de entregar a DLL em release.
- Retorno fácil: sem `--pose-gde-pilot`, GDScript permanece padrão; se classe nativa não estiver disponível, código tenta usar o fallback.
- Para obter melhoria de FPS, medir com profiler a proporção de tempo gasto no solver completo de armas/braços/poses e integrar uma tarefa maior em C++ (sem mudar autoridade/hitboxes), somente depois de testes paridade e A/B real.

## Fechamento de build multiplataforma — 10/11/2026
- **Windows x86_64:** DLLs `template_debug` (325.120 bytes) e `template_release` (305.152 bytes), compiladas via Microsoft Visual C++ e Godot-C++ API 4.7. O smoke no Godot 4.7.2 do Windows passou.
- **Linux x86_64:** bibliotecas `template_debug` (~291 KiB) e `template_release` (~287 KiB), compiladas com GCC15 no WSL Ubuntu 26.04 contra Godot-C++ API 4.7; smoke no Godot 4.7.2 Linux **PASSOU em debug e release** (classe registrada, transformação, lote).
- Dependências dinâmicas Linux observadas pelo `ldd`: `libc.so.6`, `libm.so.6` e loader. Maior versão de símbolo GLIBC encontrada com `strings`: **GLIBC_2.38** em debug e release. Isso é compatível em princípio com Ubuntu 24.04 (glibc 2.39), mas **não substitui teste no sistema real de produção**.
- **Editor/Importação:** houve um encerramento anormal ao importar pela primeira vez a extensão (Windows 0xc0000005 e Linux SIGABRT). Um projeto mínimo Linux sem GDE passou e posteriormente o projeto mínimo COM GDE passou em **3 encerramentos consecutivos**; sob GDB também encerrou normalmente. Não existe causa comprovada para o incidente original, logo esse ponto permanece como risco a revalidar em ambiente de desenvolvimento limpo.
- **Não houve ganho confiável do frame P95** nos 2 pares de testes com 28 bots reais, mesmo com a biblioteca nativa correta. O microbenchmark de 4,17x foi exclusivo da rotina matemática em lote; sua adoção de verdade exige reunir estados de muitos atores e ainda requer arquitetura/benchmark.
- Arquivos versionáveis previstos: C++, SConstruct, manifesto GDE, DLLs e .so para debug/release, funções opcionais em `GameInfantryPose`, quatro scripts de QA/benchmark, documentação. Sem edição da `main`; sem publicação da build.
