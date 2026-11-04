# IA do Modo Guerra — implementação inicial (03/11/2026)

## Escopo
Melhorar bots do Modo Guerra (Afeganistão/Ucrânia), mantendo **28 bots online** e os limites de rede atuais. O aumento para 57 bots é uma meta futura condicionada a medição.

## Arquivos alterados
- `modes/war/scripts/bot_director.gd`: percepção, combate, objetivos, navegação de veículos, resgate de ocupantes e telemetria.
- `modes/war/scripts/vehicles.gd`: atualizações de travamento de alvo dos lança-mísseis dos bots limitadas a 5 Hz, sem reduzir a frequência dos humanos.
- `qa/bot_ai_syntax_smoke.gd` e `qa/bot_ai_behavior_smoke.gd`: testes leves.

Backups locais pré-alteração:
- `modes/war/scripts/bot_director.gd.ai-backup-20261103`
- `modes/war/scripts/vehicles.gd.ai-backup-20261103`

## Comportamentos introduzidos
1. Escolha de ameaças blindadas como classe própria; antitanques utilizam o RPG ou o Stinger autorizado para a equipe via mecanismos do servidor.
2. Operadores de APC/tanque avaliam infantaria e blindados a partir do cano do veículo. Tanques escolhem arma principal contra blindados e coaxial contra infantaria. APCs priorizam o canhão 30 mm.
3. A antiga restrição de bots em Guarani/BMP por qualquer humano na partida foi substituída por prioridade temporária para humanos do mesmo time próximos do veículo.
4. Bots soldados tentam granadas com preparação/temporizador e rejeitam lançamento perto de aliados.
5. Esquadrões priorizam pontos aliados em neutralização/perda e se redistribuem entre objetivos ativos.
6. Blindados antecipam inclinações perigosas em amostras do terreno, tentam pequeno desvio validado e resgatam seus bots se não houver passagem. Humanos nunca são ejetados automaticamente.
7. Evacuação coordenada com `safe_exit()`; depois de 12 s sem saída segura, bots usam `release(id,true)` como resgate extremo para evitar ocupantes presos permanentemente. Veículos problemáticos ficam temporariamente indisponíveis à IA.
8. Atualizações complexas da IA distribuídas globalmente até ~40 decisões/s; física dos personagens continua no tick normal.
9. Contadores adicionais. Telemetria periódica opt-in, habilitada com argumento de jogo `--bot-ai-probe` (por exemplo, após o separador `--`).

## Validação já executada
- Godot 4.7.2 headless: scripts principais instanciados sem erros após geração do índice de classes.
- QA de estratégia: esquadrão priorizou defesa de ponto aliado ameaçado.
- **Não realizado ainda**: partida integrada longa com 28 bots, comprovação de disparos/lançamentos, medição de FPS/latência, rotas complexas com valas e testes multiplayer reais.
- Caso o test runner isolado falhe por classes globais ausentes, preparar a indexação do projeto via Godot Editor antes de rodar as cenas QA.

## Próximas etapas
- Teste de campo em Afeganistão e Ucrânia com relatório de quantos APCs dispararam, bots presos, granadas e lança-mísseis aceitos, tempos de resposta a pontos e picos de frame físico.
- Afinar eventuais falsos positivos da inspeção de terreno (pontes, cais, trincheiras) e corrigir rotas conforme logs.
- Planejar uso guiado do míssil TV e drones pela IA, manobras de equipe mais sofisticadas e reações individuais (cobertura, flanqueamento) com orçamento de CPU.
- Antes de qualquer mudança de 28 para 57 bots, medir a simulação e aumentar `CAPACITY`, `TEAM_LIMIT`, `ONLINE_BOTS` e a lógica de população em conjunto, sem extrapolar limites silenciosamente.
