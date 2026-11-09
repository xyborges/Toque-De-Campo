# Benchmark R2B — G3 FPP, ENet, 28 bots, JJ7 (09/11/2026)

## Veredito

**Aprovado no gate de execução e equivalência, sem ganho de FPS atribuível ao R2B.** Dez janelas válidas em cinco pares alternados de R2B desligado/ligado. Não houve queda de bots, perda de foco, desconexão, falta de materiais, erro de cache de shaders ou pacote UDP descartado. O R2B só atua visualmente na G3 FPP do jogador local e permanece **OFF por padrão**. **Não integrar à main nem publicar build apenas com este resultado**. Ambas as condições estão abaixo da meta de 60 FPS na GTX 1650.

## Ambiente e isolamento

- **Máquina:** DESKTOP-JJ7U3G3, Intel Core i5-11400H, NVIDIA GeForce GTX 1650, Windows.
- **Código-base:** `origin/main @ ce2653e`; worktree/branch exclusiva `ia/bench-realismo-r2b-jj7-20261109`, com 7 commits de realismo R1A→R2B cherry-picked, ponta do piloto `2b0dc62`. Nenhuma modificação aplicada à `main`/servidor.
- **Render:** Godot 4.7.2, Forward+, **1920×1080 real**, escala 100%, preset Médio, VSync desligado, cliente fullscreen.
- **Partida:** servidor dedicado Godot headless + cliente Godot gráfico conectados por ENet/DTLS localhost. **28 bots autoritativos** durante toda a medição, mais 1 jogador G3 FPP (29 atores no cliente). Os bots executam movimento e combate; o jogador de teste movimenta-se de verdade, sem tiros artificiais.
- **Flags:** R1A/B/C ativos em ambas as condições (`tactical_motion_pilot=true`); só `local_player.locomotion.tactical_body_pilot` alterna OFF/ON. O código físico dos bots, a autoridade, a arma real e o cano não são modificados por este teste.
- **Protocolo:** 5 pares, ordem `OFF/ON, ON/OFF, OFF/ON, ON/OFF, OFF/ON`; **3 segundos de aquecimento + 12 segundos medidos por condição**: 120 segundos de frames úteis, 30 segundos de aquecimento. Deslocamento local oscilante em ciclos de 2 s por sentido, para evitar atingir o combate ao fim de sucessivas janelas. ~52,3 a 52,5 metros de caminho percorrido em cada janela (não confundir com deslocamento líquido).
- **Critérios automáticos:** 28 bots replicados, G3 preservada em toda a janela, FPP local, R2B ON somente quando elegível, pose com sinal diferente de zero no cenário ON, movimento efetivo, zero perda de foco, zero desconexão e processo encerrado corretamente. Todos passaram.

## Medições por par

| Par | FPS OFF | FPS ON | FPS ON vs OFF | P95 OFF / ON (ms) | P99 OFF / ON (ms) | Δ P99 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 37,03 | 35,54 | −4,01% | 34,96 / 37,90 | 45,70 / 44,40 | −2,83% |
| 2 | 34,35 | 35,87 | +4,42% | 46,90 / 37,06 | 69,11 / 46,06 | −33,36% |
| 3 | 37,64 | 38,14 | +1,34% | 36,75 / 36,33 | 44,32 / 41,61 | −6,10% |
| 4 | 42,90 | 38,08 | −11,25% | 31,25 / 37,00 | 41,19 / 49,46 | +20,10% |
| 5 | 40,08 | 42,92 | +7,08% | 38,08 / 34,08 | 52,65 / 46,09 | −12,46% |

**Agregação:**
- Mediana dos FPS de cada condição: **OFF 37,635**; **ON 38,076**.
- Mediana das **mudanças pareadas** de FPS: **+1,339%**; **3/5** pares favorecem ON.
- Mediana das **mudanças pareadas** de P99 em milissegundos: **−6,104%**; **4/5** pares favorecem ON.
- Mediana **dos P99 absolutos de cada condição**: **OFF 45,695 ms; ON 46,056 ms**. Esta mediana é diferente da mediana das variações pareadas; ambas estão corretas matematicamente, mas não significam a mesma coisa.
- Os tempos de quadro variaram significativamente de janela para janela. **Não há evidência robusta de aumento de FPS causado por um cálculo visual de um único ator**. O melhor P99 pareado é um sinal favorável, mas sem consistência suficiente para promessa de desempenho geral.
- Sob estas condições, ~38 FPS é **inferior à meta de 60 FPS** da GTX 1650. A otimização prioritária de FPS permanece em outras partes do render, bots e física.

## Validação de estabilidade

| Validação | Resultado |
| --- | --- |
| Pares completos | **5/5** |
| Janelas válidas | **10/10** |
| Bots autoritativos mínimos / finais | **28 / 28** |
| Atores remotos mínimos | **28** |
| GPU / renderer / escala | **GTX 1650 / Forward+ / 100%** |
| Janela / resolução real | **Fullscreen / 1920×1080** |
| Perdas de foco / desconexões registradas | **0 / 0** |
| G3 perdida / falta de pose quando ON | **0 / 0** |
| Erros de script ou parsing | **0** |
| Falhas no carregamento de materiais | **0** |
| Erros de criação do shader cache | **0** |
| Avisos de buffer UDP cheio | **0** |
| Saída dos processos server e client | **0 / 0** |

## Diagnósticos descartados (não contam como resultados)

1. O novo worktree teve falha nativa do import inicial do editor, `-1073741819`, e iniciou com cache parcial. Foram reutilizados exclusivamente os arquivos importados `.godot/imported` e o índice UID da mesma revisão da `main`; ambos são caches locais ignorados pelo Git. Isso eliminou materiais ausentes que deixavam o chão cinza.
2. O caminho longo inicial de `APPDATA` gerou mensagens `Unable to create shader cache directory`. Foi trocado para diretórios curtos de QA em `LOCALAPPDATA/tdc-r2b-jj7-qa/{server,client}`, sem compartilhar dados entre processos.
3. A primeira bateria prolongada foi invalidada na quarta repetição, porque o jogador percorreu centenas de metros continuamente e a G3 deixou de estar equipada. Foi substituída por um trajeto alternado curto, conferindo o identificador da G3 e a identidade do jogador durante toda a medição.
4. Nenhum dos valores destes ensaios incompletos entrou na tabela final.

## Reprodutibilidade

Arquivos versionados:
- `tests/qa_r2b_enet_28bots.gd` — instrumentação Godot e critérios de paridade;
- `tests/run_qa_r2b_enet_28bots.py` — duas instâncias Godot, DTLS localhost, alternância, veredito e limpeza;
- `docs/benchmark-results/r2b-jj7-20261109/verdict.json` — dez medições e metadados de validação;
- `docs/benchmark-results/r2b-jj7-20261109/pairs.csv` — pares e métricas comparáveis.

O runner utiliza um certificado de teste localhost, **não versionado**; gerá-lo como `work/r2b-bench-jj7/tls/test.crt` e `test.key`. Exemplo (com OpenSSL disponível e a engine 4.7.2 instalada):

```powershell
New-Item -ItemType Directory -Force work/r2b-bench-jj7/tls | Out-Null
openssl req -x509 -nodes -newkey rsa:2048 -days 365 -subj '/CN=localhost' -addext 'subjectAltName=DNS:localhost,IP:127.0.0.1' -keyout work/r2b-bench-jj7/tls/test.key -out work/r2b-bench-jj7/tls/test.crt
python tests/run_qa_r2b_enet_28bots.py --engine 'C:\caminho\Godot_v4.7.2-stable_win64_console.exe' --pairs 5 --seconds 12 --timeout 700
```

**Limites:** localhost não reproduz latência de Internet nem comportamento de jogadores humanos; cinco janelas pareadas são um piloto, não um teste estatístico conclusivo. A geometria da G3 continua sendo o modelo procedural atual `scripts/g3_model.gd`; o R2B não melhora suas malhas. Esta auditoria não valida R2C física, collision rig novo ou capacidade de 50+ bots.

**Recomendação:** preservar R2B como piloto opt-in para inspeção visual/humana, **OFF por padrão**; não usá-lo como justificativa para afirmar aumento de desempenho, e não avançar R2C física sem seus próprios testes de hitboxes, arma/cano, multiplayer e P99.
