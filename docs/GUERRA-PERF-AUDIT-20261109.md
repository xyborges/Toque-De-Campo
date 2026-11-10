# Guerra/Favela: auditoria de otimização e controles reproduzíveis

Base: origin/main `e8891aedce71065b4ce52bee1bbaae401269d80a`.
Branch: `codex/jj7-guerra-perf-audit-20261109`.
Máquina desta coleta: i5-11400H, NVIDIA GTX 1650, Windows, Godot 4.7.2,
Forward+, 1920×1080, Médio, escala 100%, 28 bots, física 60 Hz, sem VSync/limite de FPS.

## Escopo e critérios

Primeira etapa da fila: verificar as premissas e medir o teto de seis intervenções
antes de modificar combate, colisões, rede ou velocidade da simulação. Os controles
são exclusivos de testes, inacessíveis pelo fluxo normal do jogo. A configuração
padrão de produção continua igual. Nenhuma aprovação de 60 FPS ou de publicação.

O texto recebido combina máquinas, durações e momentos diferentes. Seus números
históricos são hipóteses de partida; esta coleta usa exclusivamente a máquina acima.
O branch de fluxo GitHub ainda não está integrado à main: o documento obrigatório
foi lido em origin/ia/github-centralizacao-20261108. PRs #5 (canelas/dano) e #6
(regressões de combate/UI, baseado em #5) estavam abertos; não foram incorporados.

## Auditoria do texto recebido

| Proposta | O que o código atual permite concluir | Decisão |
|---|---|---|
| Limitar catch-up a 2/3 | Limita ticks por quadro, não todos os custos do quadro nem matematicamente o percentil 99. Pode trocar travadas por tempo simulado mais lento. | Medir ticks/quadro, FPS, P99 e razão simulação/tempo real; manter padrão 8 fora do teste. |
| Colisão bot–bot | A separação por script não é prova de equivalência física em filas, escadas ou multidões. Mudar layers também afeta consultas, veículos e jogadores. | Testar exceções simétricas apenas entre bots, conservando layers/masks; promoção exige QA funcional e ENet. |
| Hitboxes | monitoring=false e monitorable=false não demonstram retirada do espaço físico. Reduzir 16 regiões para 4 altera dano/oclusão sem substituição equivalente. | Comparar consultas desligadas com área realmente fora do espaço físico, em controles separados e destrutivos. |
| Caminho específico de bot | Listener e câmera já têm guardas locais; óptica e timers continuam no caminho compartilhado. Pitch/lean zero não bastam para ignorar toda pose. | Não duplicar o loop físico inteiro nem retirar pose balística sem paridade de estados e armas. |
| Diretor | O ator já é obtido uma vez no laço; há lookup repetido do registro antes/depois de _move. O tiro já exige alvo válido/line_clear. | Microajustes precisam de A/B; não repetir reescrita de _near_actors. |
| Mapa tático | _prepare já executa uma vez por widget; refresh tem assinatura e cache de até 8 estados territoriais. O raster de terreno é calculado mesmo se depois substituído por cartografia preparada. | Há desperdício de carregamento verificável, mas não geração integral a cada refresh. Cache global precisa de chave por operação/identidade. tactical_map é fonte do manifesto Ukraine: alteração requer regeneração oficial. |
| HUD | update_hud faz find_child ShopButton e percorre jogadores; WarGame chama super. Atualizações podem ser coalescidas, mas feedback de dano e morte precisam continuar imediatos. | Candidato posterior, com teste de estado e latência de UI; não prometer milissegundos sem medir. |
| Efeitos | WarEffects já usa MultiMesh/pool, mas varre 256 slots; projéteis já têm lista ativa, flashes ainda varrem 48 posições. | Separar otimização da varredura de uma troca visual; verificar expiração, sobrescrita do pool e flashes. |
| Servidor | WarEffects._ready já desliga _process em headless; ragdolls já são omitidos e mundo Guerra tem guardas de visualização. | Auditar lacunas específicas; não tratar tudo como trabalho ainda realizado no dedicado. |
| Rede | Guerra retransmite imediatamente poses validadas; loop genérico pula essas poses. Impacto não sanguíneo pode enviar dois RPCs reliable. | Medir com clientes reais. Batching, unreliable e interesse espacial alteram ordem/alcance/latência; exigem QA, não são correções automaticamente seguras. |
| Colisores estáticos | Menos shapes pode ajudar, mas fundir convexos pode fechar acessos, gerar vãos ou alterar cobertura. | Etapa própria, com reservas de cenas, navegação e mapas preparados; não reduzir proteção por LOD. |
| Ideias já reprovadas | 40 Hz, Jolt em outra thread, cache de degraus e reescrita de _near_actors têm histórico negativo no material recebido. | Não repetir sem nova hipótese causal. R2C permanece como na base, experimental OFF. |

## Ferramenta adicionada

`tests/benchmark/war_perf_controls.gd` estende o benchmark gráfico oficial por quatro
hooks neutros (_make_game, _after_deploy, _sample_extra, _result_extra). O cenário,
seed, câmera, qualidade, métricas e rastros por quadro continuam sendo os oficiais.

Controles: baseline; no-monitoring; no-hitbox-space; no-presentation;
no-bot-contact; steps-2; steps-3. Somente bots são alvos das ablações. Hitboxes
locais ficam preservadas. No contato, são verificadas 28×27=756 exceções direcionais.
Nas áreas, esperam-se 28×16=448 regiões. Novas instâncias recebem o mesmo controle.
Desativar apresentação também altera as transformações usadas por hitboxes; o
resultado é teto diagnóstico, nunca uma versão jogável aprovada.

O executor reserva os arquivos de saída, recusa resultados antigos, executa
serialmente, preserva logs, checa erros e processos concorrentes, aplica os critérios
oficiais de integridade (foco integral, população estável, VSync/FPS, resolução,
rastro de quadros e GPU sincronizada) e registra os hashes de fontes GDScript.
Telemetria bruta de temperatura/clock da GPU dentro da janela acompanha o relatório.
Temperatura/clock efetivo da CPU não foram instrumentados: limitação explícita.

Reprodução da triagem:

```powershell
python tests/benchmark/run_perf_controls.py --pairs 2 --duration 30 --prefix coleta-nova
```

O prefixo deve ser novo. Para A/A: `--controls baseline`. Para homologação, usar
`--pairs 5 --duration 120`, A/A primeiro, seguida dos candidatos selecionados.
O processo verifica concorrência antes e durante as rodadas, mas essa amostragem
não detecta necessariamente toda interferência breve de outros programas.

## Resultados

Foram executadas 32 rodadas de 30 s (8 s de aquecimento), 29 válidas e 3 inválidas
por falta de foco desde o início. Os três pares afetados foram repetidos por inteiro;
nenhum resultado inválido entrou na tabela. São 12 pares A/B completos em ordens
inversas (2 por controle) e um A/A curto. Duas rodadas adicionais de smoke de 10 s
validaram inicialmente a ferramenta e foram excluídas desta análise.

**Todos os 29 resultados válidos falharam na referência de aceitação de desempenho;
nenhuma ablação chegou a 60 FPS médios.** O conjunto de metas (incluindo 1% low,
P95/P99 e quadros longos) também não foi aprovado. Não houve aprovação de gameplay,
rede ou build. A temperatura da GPU na janela ficou entre 58.0 e 75.0 °C; isso não
substitui telemetria de temperatura/clock efetivo da CPU, ausente nesta coleta.

Valores: baseline → controle; no A/A, primeira → segunda baseline. Física é o
monitor oficial amostrado por quadro. Simulação % é ticks do histograma / 60 Hz /
tempo total do rastro, incluindo o primeiro intervalo. O relógio do jogo original
foi preservado nos dados, mas começa na primeira amostra e exclui o primeiro
intervalo: não confundir as duas janelas.

| Controle / par | FPS médio e variação | Física média (ms) | P99 quadro (ms) | Simulação / real (%) |
|---|---|---|---|---|
| no-monitoring / 1 | 36.22 → 37.59 (+3.80%) | 17.171 → 17.142 | 55.616 → 59.191 | 99.958 → 99.930 |
| no-monitoring / 2 | 42.34 → 43.26 (+2.17%) | 16.301 → 16.113 | 35.951 → 36.637 | 99.990 → 99.864 |
| no-hitbox-space / 1 | 43.60 → 43.05 (-1.26%) | 16.558 → 16.413 | 36.914 → 58.667 | 99.989 → 99.950 |
| no-hitbox-space / 2 | 44.66 → 46.77 (+4.71%) | 15.706 → 15.824 | 34.708 → 33.561 | 99.973 → 99.981 |
| no-presentation / 1 | 43.86 → 54.16 (+23.49%) | 15.987 → 11.707 | 35.792 → 29.451 | 99.986 → 99.940 |
| no-presentation / 2 | 43.87 → 55.63 (+26.80%) | 15.982 → 11.345 | 36.869 → 28.572 | 99.880 → 99.992 |
| no-bot-contact / 1 | 43.68 → 43.65 (-0.08%) | 16.018 → 16.301 | 35.394 → 35.917 | 100.006 → 100.007 |
| no-bot-contact / 2 | 42.70 → 44.42 (+4.03%) | 16.977 → 16.580 | 41.040 → 35.615 | 99.988 → 99.925 |
| steps-2 / 1 | 43.55 → 43.86 (+0.72%) | 16.511 → 16.462 | 36.980 → 35.484 | 99.953 → 99.540 |
| steps-2 / 2 | 43.44 → 44.69 (+2.89%) | 15.868 → 16.347 | 35.874 → 35.338 | 99.934 → 99.517 |
| steps-3 / 1 | 43.04 → 44.53 (+3.46%) | 16.303 → 16.234 | 43.884 → 35.231 | 99.929 → 99.652 |
| steps-3 / 2 | 42.92 → 43.71 (+1.86%) | 16.486 → 16.523 | 37.165 → 38.689 | 99.963 → 99.624 |
| baseline / 1 | 44.80 → 43.03 (-3.94%) | 16.577 → 16.636 | 35.112 → 36.147 | 99.977 → 99.943 |

Evidência completa: [JSON consolidado](benchmark-results/guerra-perf-audit-20261109.json),
com 32 rastros, dados brutos de GPU, verificações de integridade, hashes, contadores
de combate e identificação dos pares selecionados. O consolidado foi relido e os
32 relatórios foram comparados aos arquivos originais, sem alterar valores.

### Interpretação e próxima prioridade

1. **Apresentação** é o teto mais promissor: +23,49%/+26,80% FPS e redução de
   4,28/4,64 ms de física nas duas ordens. Ainda fica em 54,16/55,63 FPS e altera
   hitboxes/arma; não é uma otimização jogável. Priorizar sondas de corpo, arma/IK
   e setters, mantendo transformações finais, cadência e dano equivalentes. O código
   já tem cache em WarHumanRig.pose; uma proposta nova precisa considerar esse cache.
2. **Contato bot–bot** não confirmou economia de 1–3 ms: física +0,28/-0,40 ms,
   com resultado não consistente. O segundo ganho de FPS (+4,03%) é próximo à
   variação observada no A/A (-3,94%); um único A/A não estima intervalo de confiança.
   Não há justificativa para promover mudança de colisão sem mais evidência e QA.
3. **Áreas físicas** não confirmaram economia >1,5 ms: retirar áreas deu
   -0,145/+0,118 ms; monitorable desligado deu -0,029/-0,187 ms. As ablações alteram
   dano e combate, então tampouco provam o custo nativo puro em um replay idêntico.
4. **Catch-up** não resolve o orçamento por bot. Limite 2 melhorou P99 apenas
   1,49–4,05%; limite 3 melhorou em uma ordem e piorou na outra. O limite 2 conservou
   ~99,52–99,54% da velocidade do motor nesta carga curta, mas o pior quadro ainda
   foi ~164 ms. Sob carga maior/longa pode desacelerar mais. Padrão de produção
   permanece 8; uma decisão de gameplay exige cenários de sobrecarga e ENet.
5. A baseline inicial de 36,22 FPS ficou abaixo das posteriores de ~43–45 FPS,
   mesmo com o smoke anterior; foi preservada. Cache, clocks e evolução do combate
   reforçam a necessidade de A/A longo antes de promover ganhos.

### Verificações executadas

- Importação inicial Godot 4.7.2: exit 0. O primeiro caminho relativo de log não
  existia e produziu erro de abertura; a validação posterior usou pasta criada e
  log absoluto. A importação inicial não é alegada como execução sem mensagens.
- `--headless --check-only --script res://tests/benchmark/war_perf_controls.gd`:
  PASS, exit 0, inclusive depois do reparo de foco. UID gerado pelo Godot.
- `python -B -m unittest discover -s tests/benchmark -p test_runner.py`:
  **11/11 PASS**, inclusive perda de foco, rastro e GPU inválidos.
- 32 execuções gráficas: **29 coletas válidas / 3 inválidas retidas**; 6/6 tentativas
  de repetição e 2/2 A/A válidas. Controles sem erros de script, 448 áreas e 756
  exceções direcionais verificadas quando aplicáveis. Erros de controle/source
  interrompem o executor; coletas inválidas ao final retornam exit 4.
- `git diff --check` e guard de staged: PASS nos commits de código.
- Não executados: 5 pares A/A e 5 A/B de 120 s, QA de contato/escadas/atropelamento,
  paridade completa de poses/dano e clientes ENet. Nenhuma mudança de produção
  depende desses testes nesta entrega, porque ela contém somente instrumentação.

Comandos da recuperação e A/A, com prefixos novos em cada reprodução:

```powershell
python tests/benchmark/run_perf_controls.py --controls no-monitoring,no-hitbox-space,no-bot-contact --pairs 1 --pair-offset 1 --duration 30 --prefix repeticao-nova
python tests/benchmark/run_perf_controls.py --controls baseline --pairs 1 --duration 30 --prefix aa-novo
```


## Limites e riscos

Cenário offline de câmera fixa com bots/combate reais, sem clientes remotos ou
trajetória humana. Seed fixa não garante replay idêntico: combate, movimento,
respawns, gait por relógio de parede e decisões podem divergir entre processos.
Contadores de tiros/deployments são preservados para examinar essa diferença.
A distribuição do monitor de física é amostrada por quadro, não uma medição
independente de cada passo nativo. Escopos inclusivos não podem ser somados como
se fossem partes exclusivas de um tick.

Separar validade da coleta, ganho relativo e atendimento da meta. Uma rodada pode
ser válida e ainda falhar em 60 FPS/P99/1% low. Shader/cache aquecido, temperatura,
foco e variação de combate exigem cautela; o par curto inicial de smoke não integra
a conclusão de desempenho. Nenhum ganho de FPS é garantido pela contagem de chamadas.

Rollback desta entrega: reverter seus commits de instrumentação/documentação;
nenhum asset, cena de usuário, áudio, mapa preparado ou padrão de gameplay é alterado.
