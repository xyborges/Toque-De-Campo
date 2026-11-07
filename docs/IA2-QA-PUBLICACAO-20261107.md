# Toque de Campo — QA de publicação IA2 — 7 de novembro de 2026

**DECISÃO: HOLD. Não publicar uma nova build.** A build pública 95 / versão 1.13.8 continua sendo a versão de distribuição. Não alterar manifesto, assinatura, launcher ou servidores. A `main` do GitHub já contém as três otimizações experimentais, **desligadas por padrão**.

## Fonte de verdade e Favela

- Repositório GitHub: `xyborges/Toque-De-Campo`.
- Commit-base da worktree QA: `ee969afc8a889861c64639689087c1568d9bfb4b`; branch exclusiva `ia/qa-ia2-release-20261107`.
- A `main` **já possui a Favela atualizada e publicada na 1.13.8**, incluindo o baile e as seis músicas sincronizadas. Hash do objeto `modes/war/scripts/favela_layout.gd` na `main`: `663d1cfe31b6` (abreviado).
- O protótipo experimental **Favela v25** da IA2 está em branches distintas. Um cherry-pick de otimização desse protótipo havia conflitado com a `main`, mas isso não significa ausência da Favela publicada. **Não reconstruí nem substituí o mapa**.

## 1. Multiplayer ENet — novo teste de admissão e deploy

Instrumentação e runner em `tests/ia2_qa_multiplayer_network.gd` e `tests/run_ia2_qa_multiplayer.py`. Servidor local Godot headless e cliente gráfico em **processos distintos** na DESKTOP-JJ7U3G3, Godot 4.7.2/Jolt, autenticação de contas de teste, certificado DTLS **temporário e local em `work/`**, Forward+, 1080p, Favela da `main`.

| Rodada | Servidor | Cliente | Bots online | Deploy | Falhas | FPS cliente | P99 cliente |
|---|---|---|---:|---|---:|---:|---:|
| `favela-enet-28-a` | PASS | PASS | 28 | PASS | 0 | 3,81 | 272,20 ms |
| `favela-enet-cap-a` | PASS | PASS | 28 | PASS | 0 | 39,44 | 43,73 ms |
| `favela-enet-cap-b` | PASS | PASS | 28 | PASS | 0 | 42,17 | 36,52 ms |

Todos os testes tiveram 29 personagens no cliente, 28 bots remotos, foco de janela preservado e emissão dos relatórios pelo próprio servidor e cliente. O teste A/B de limite de cadáveres criou 12 ragdolls **diretamente na apresentação do cliente conectado**:

- `cap-a`: comportamento original, **11 corpos**.
- `cap-b`: flag `TDC_IA2_RAGDOLL_STRICT_CAP` simulada no cliente, **10 corpos**.
- A correção funcional passou. Um par online **não comprova ganho estatístico de FPS**.
- A primeira partida a 3,81 FPS mostra elevada variabilidade entre execuções; possíveis custos de aquecimento/importação, compilação de shader e concorrência no mesmo computador não foram isolados.

**Escopo do gate:** isto confirma a ligação ENet, admissão, deploy, recepção de 28 bots e integridade da apresentação de cadáveres no cliente. **Não substitui** a suíte multiplayer completa com tiros/hitreg, veículos, granadas, reconexão e cliente em outra máquina. O fixture antigo `war_multiplayer.gd` tinha falhado no baseline; foi criada uma validação atual independente sem alterar o código de produção.

### Cliente e servidor em máquinas separadas

Ambos os desktops possuem endereços na rede local, mas os testes ICMP e de envio UDP de teste da JJ7U3G3 para a R0I0NQG não confirmaram comunicação entre as máquinas. **Nenhuma regra de firewall foi alterada**. Portanto o benchmark online no cliente acima sofre concorrência de CPU com o servidor local, e não determina o FPS esperado de cliente conectado ao Ubuntu de produção.

## 2. Ambiente/ruído do benchmark

Foram observados processos de usuário concorrentes, inclusive `SIMNext.LocalRecording`, `NitroSense` e `RobloxCrashHandler`. Nenhum foi encerrado ou configurado sem autorização. Para as dez rodadas de comparação da Favela, a GTX 1650 foi monitorada continuamente com `nvidia-smi`:

- Temperatura máxima por execução: **59 a 61 °C**.
- **Zero** amostras de thermal slowdown da GPU nos dez testes.
- Resolução **1920×1080**, escala **100%**, qualidade **Média**, **Forward+**, 28 bots (14/14), foco em todos os quadros, VSync e limitador desligados.
- Cada execução: 6 s de warmup e 14 s de medição. Uma intervenção por teste, 5 pares alternados na ordem AB, BA, AB, BA, AB.
- Persistem possíveis flutuações de **CPU/processos em segundo plano**, além de cenário/posição do cliente. Temperatura e clocks da CPU não foram registrados. Não se deve extrapolar o FPS para outra máquina ou online independente.

## 3. Cinco pares na Favela — limite estrito de cadáveres

A = controle antigo, B = correção estrita; ambos mantêm 28 bots com IA real e aplicam uma rajada sintética de 12 mortes na apresentação.

| Par | FPS A | FPS B | P99 A (ms) | P99 B (ms) | Corpos A | Corpos B |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 23,44 | 23,00 | 89,37 | 129,66 | 11 | 10 |
| 2 | 22,85 | 23,56 | 101,48 | 98,83 | 11 | 10 |
| 3 | 23,58 | 22,55 | 93,98 | 87,79 | 11 | 10 |
| 4 | 23,01 | 23,55 | 127,30 | 89,60 | 11 | 10 |
| 5 | 23,63 | 23,51 | 79,94 | 73,00 | 11 | 10 |
| **Média** | **23,30** | **23,23** | **98,41** | **95,78** | **11** | **10** |

- FPS médio mudou **−0,29%** (piorou ligeiramente); não há ganho acima do ruído.
- P99 médio melhorou **2,68%**, mas a melhora não foi consistente em todos os pares; P99 da partida continua muito acima da meta de 33,3 ms.
- Quadros com mais de um tick físico: **97,43% em A**, **98,21% em B**. O indicador **piorou**.
- Todas as dez execuções do fixture foram válidas (zero perda de foco, 28 bots), sem throttling da GPU. Dados em `work/ia2-qa-20261107/favela-five-pairs-summary.json` e JSON/GPU CSV individuais em `work/` da worktree QA.
- **Decisão de performance: reprovado.** **Decisão de funcionalidade: correção aprovada em testes sintéticos offline e no cliente ENet**, ainda sem regressões de tiroteio e todo o multiplayer.

## 4. Flags avaliadas anteriormente

- `TDC_IA2_REUSE_RESPAWN_WEAPON`: 28,09 FPS controle vs 25,90 FPS otimizado em cinco pares no Afeganistão, apesar de excelente ganho no callback isolado. Não habilitar.
- `TDC_IA2_DEFER_REMOTE_RAGDOLL`: 26,14 vs 26,53 FPS em um único par; P99 piorou de 92,93 para 98,43 ms. Não habilitar.
- `TDC_IA2_RAGDOLL_STRICT_CAP`: no Afeganistão +14,4% FPS médio em cinco pares, mas abaixo dos 38,94% de amplitude/ruído do controle. Favela reavaliada acima, sem ganho mensurável. Manter opt-in.

## Verificação de integridade do editor

A importação inicial em uma worktree de QA registrou avisos `Cannot go into subdir` para diretórios de hashes. Investigação identificou os caminhos exatos sob `work/ia2-qa-20261107/appdata-*/Godot/app_userdata/.../shader_cache/`, criados pelos clientes de teste. **Não eram erros de GDScript ou assets ausentes da Favela.** Os runners passaram a criar `.gdignore` nos diretórios temporários de relatórios/caches (arquivos ignorados no Git, sem remover os caches existentes). A nova importação do editor Godot 4.7.2 terminou com **exit 0, zero erros de scanner e zero `SCRIPT ERROR`**.

## Decisão operacional e pendências

1. **Não publicar build 96 / 1.13.9**, nem ativar flags experimentalmente na versão pública. A versão estável 95 / 1.13.8 permanece.
2. A correção do limite de cadáveres é válida como bugfix local, mas um hotfix global ainda requer regressões visuais (FPP/TPP, cadáveres no cliente em combate normal, colisões, armas, granadas, reconexão) e teste ENet completo.
3. Resolver a conectividade entre os desktops para separar hardware de servidor e cliente; qualquer mudança de firewall exige decisão do operador.
4. Investigar CPU/threading/vegetação/poses e a diferença frio/quente da primeira execução para melhorar o P99. Não mascarar o teste reduzindo 28 bots, resolução ou distância de renderização.
5. Executar nova matriz de cinco pares só quando uma alteração demonstrar potencial real de ganho consistente, em vez de repetir experimentos reprovados.

## Arquivos tocados

Somente novos artefatos de QA em worktree isolada:

- `tests/ia2_qa_multiplayer_network.gd` (+ UID de importação, quando gerado): fixture ENet com modo opcional de rajada de cadáveres na apresentação do cliente.
- `tests/run_ia2_qa_multiplayer.py`: servidor e cliente, certificado DTLS temporário, relatórios e logs isolados.
- `tests/ia2_qa_real_war_benchmark.gd` (+ UID): cópia identificável do runner já validado da IA2, sem mudanças em produção.
- `tests/run_ia2_qa_release.py`: cinco pares Favela com GPU/telemetria e validação de resultados.
- Este relatório.

Os logs, dados brutos, certificados de teste, importações automáticas da Godot, credenciais locais de teste e caches ficam em `work/` ignorado. **Nenhum script de produção, mapa, servidor, assinatura, manifesto, branch `main` ou build publicada foi modificado.**
