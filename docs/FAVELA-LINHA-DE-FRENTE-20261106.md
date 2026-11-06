# Favela — protótipo de Linhas de Frente (06/11/2026)

**Branch:** `ia/favela-linha-frente-20261106`
**Base:** `main` no commit `8b867c4` (1.13.8/build 95 publicada anteriormente).
**Escopo:** protótipo de desenvolvimento, isolado; não integrado nem publicado.

## Intenção

Resolver dispersão de 28 bots e jogadores em cinco bandeiras simultâneas. A Favela agora tem uma única área disputável, e a vitória se consegue ao atravessar progressivamente todos os setores em direção à base inimiga. Continuam existindo vielas, coberturas, motos e Guaranis; várias rotas de aproximação, **mas apenas uma frente ativa**.

## Cinco setores, ordenados da Polícia para os Bandidos

| Ordem | Setor | Nome | X | Z |
|---|---|---|---:|---:|
| 1 | A | Portal norte | -265 | 345 |
| 2 | B | Escadaria | -170 | 155 |
| 3 | C | Praça central | -85 | -20 |
| 4 | D | Lajes do alto | 270 | -205 |
| 5 | E | Campo de futebol | 430 | -275 |

A **Polícia** começa controlando A/B, os **Bandidos** D/E, e C está neutro e contestável. A captura de C avança a frente para D se feita pela Polícia, ou para B se feita pelos Bandidos. Contra-ataques fazem a frente recuar, sem permitir capturas de áreas trancadas atrás dela. Vence imediatamente quem tomar a última área do território inimigo: E (Polícia) ou A (Bandidos). Em caso de tempo/tickets esgotados, prevalece quem fez a frente avançar mais; se a frente estiver em C, tickets decidem o desempate.

### Locais de implantação

Somente base principal ou setor aliado imediatamente atrás da frente. A validação é da **autoridade do servidor**; menu de spawn, IA e mapa tático usam a mesma regra. Bots se dirigem à frente única. Isso evita que jogadores reapareçam no extremo oposto da Favela e que 28 bots pulverizem-se por cinco objetivos.

### HUD

A barra superior da Favela passa a ser linear A→E, com alvo ativo destacado, nome do setor e temporizador/tickets separados. Os mapas Guerra Ucrânia/Afegão mantêm seus controles e esquema de captura anteriores.

## Morros ao redor do cenário

`favela_rim.gd` adiciona elevação física e determinística somente na faixa externa a partir de ±640 m, até ±750 m, com cume variado (até ~92 m de incremento máximo teórico). As 18 rotas existentes, bases e áreas dos cinco objetivos permanecem na área onde a elevação nova é zero. A versão online/autoridade usa a mesma função de altura que a versão cliente. Os materiais e vegetação natural do mapa continuam aplicados.

### Campo de futebol

O ponto E está sobre o centro físico real do campo existente (`430,-275`), **preservando o baile, música e recursos já construídos**. A borda do platô passa por transição de 110 m em vez de 12 m; a auditoria da viela 16 apontou inclinação máxima **0,210**, contra **0,802** na `main` de base e **0,88** no primeiro protótipo.

## Testes em Godot 4.7.2

- `favela_frontline_qa.gd`: **63 verificações aprovadas**, incluindo avanço, reversão, vitórias dos dois lados, território acima de tickets, respawns e regressão na Ucrânia.
- `favela_spatial_review.gd`: PASS, 0 casas entrando em ruas, 0 lotes sobrepostos; 4.197 lotes.
- `favela_architecture_qa.gd`: PASS, 11.600 amostras de suporte e folga, 154 escadarias, 25 passarelas.
- `favela_runtime_qa.gd -- --favela-bots`: PASS 39/39, 28 bots e oito veículos.
- `favela_operation_smoke.gd -- --favela-visuals`: PASS, ~101.892 instâncias visuais.
- Manifesto oficial: versão de desenvolvimento **19**, 66 fontes, MATCH.
- Importação Godot `--editor --import`: completou reimportação, mas houve exit code `-1073741819` (violação de acesso na saída). Os testes `--headless --script` executaram com sucesso.

## Pendências para release

- ENet com 28 bots + 2 jogadores + servidor: PASS 18/18 (8 servidor, 5 por cliente), log em TEMP/favela-frontline-enet-20261106.log.
- ENet de conquista real: Policia captura C -> D, Bandidos capturam D -> C, com snapshots/respawns verificados em ambos os clientes: PASS 16/16 (8 servidor e 4 por cliente), log em TEMP/favela-frontline-live-enet-20261106.log.
- Continuam pendentes testes de desconexao/reconexao durante mudanca de frente e benchmark isolado.
- Executar benchmark isolado de frame time/FPS 1080p com 28 bots, especialmente custo das novas elevações.
- Fazer playtest humano: tempos reais entre B/C/D/E, combate no campo e rotas laterais. A distância C→D ainda é maior que os demais trechos (~400 m), apesar do foco único; pode ser ajustada em revisão de layout com nova auditoria de escadas/ruas.
- Validar visualmente os morros das quatro direções, vegetação, fundos e neblina para garantir horizonte convincente.
- Não executar merge para `main`, build nem deploy sem QA final.

As mudanças estão preservadas em worktree separada. Não encerrar outras sessões de IA nem sobrescrever trabalho já publicado.

## Fechamento

Os dois testes multiplayer retornaram FAVELA_ENET_PASS. O codigo fica em branch separada; sem merge, push nem implantacao da versao 1.13.8/build95. Distancias entre setores e silhuetas dos morros ainda precisam de validacao visual e playtest humano antes de decidir pela publicacao.
