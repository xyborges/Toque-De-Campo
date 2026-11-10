# Limite provisório de bots — 11 por time (09/11/2026)

**Esta mudança é uma política temporária de população, não uma correção de desempenho.** A investigação das poses, do Jolt e da separação entre atores continua em `ia/bot-physics-pose-jj7-20261109` (relatório `docs/BOT-PHYSICS-POSE-AUDIT-JJ7-20261109.md` naquela branch). Nenhum ganho de FPS é atribuído a este limite.

## Abrangência

- **Guerra (Ucrânia, Afeganistão, Favela):** máximo de 11 **bots** por equipe em salas online, sem contar humanos. O equilíbrio com humanos permanece: quando uma equipe humana cresce, o diretor reduz bots no lado apropriado, sem ultrapassar 11 no outro lado. A soma pode ficar abaixo de 22 em salas com equipes humanas muito desiguais.
- **Treino Guerra offline:** mantém os menus existentes de 12 ou 18 participantes (humano incluído); `populate` limita a 11 bots por lado caso configurações futuras solicitem mais.
- **Battle Royale:** não existe equipe; máximo de **22 bots no total** na sala online, além dos humanos (limite existente: 12). Offline continua com 8 participantes totais e não foi reduzido.
- **Naval:** a inspeção dos scripts atuais não encontrou um diretor de bots. Não foi inventada uma população nova para esse modo.
- **QA e desempenho futuro:** no modo Guerra, SOMENTE instâncias marcadas ao mesmo tempo com `test_mode=true` e `online_bots_test=true` preservam o comportamento histórico de 28 bots (14 por equipe). Treinos offline com `test_mode=true` também preservam contagens explícitas dos fixtures. Assim, os testes de 28 e 57 bots podem continuar medindo o teto futuro sem afetar servidores comuns.

## Arquivos e responsabilidades

- `scripts/bot_population_limits.gd`: política central, 11 bots por equipe e 22 por sala FFA; helper de balanceamento com desvio limitado por equipe.
- `modes/war/scripts/rules.gd`: expoe `ONLINE_BOTS_PER_TEAM` e `ONLINE_BOTS` a partir da política central; limites de humanos, capacidade, regras de equipes e rede preservados.
- `modes/war/scripts/bot_director.gd`: usa o helper para objetivos de população online e respeita o máximo offline, exceto QA explícito.
- `modes/battle_royale/scripts/game.gd`: usa os 22 bots como total FFA; mantém admissão humana independente.
- `tests/bot_population_limit_11.gd`: testes de paridade de limites, desequilíbrio humano, bypass estrito de QA e preservação dos 28 bots em fixtures.
- `tests/1102_br_population.gd`: regressão da fila BR atualizada para os novos 22 bots.

## Não alterado por esta fase

Colisões, `move_and_slide`, `test_move`, 60 Hz da física, IA de cobertura, navegação, busca de objetivos, hitboxes, poses, armamentos, quantidades de humanos, regras de dano, renderizador e escala de resolução.

Esta alteração **não substitui** a investigação de performance: a meta na GTX 1650 continua sendo 60 FPS com P99 ≤33,3 ms, e o objetivo de expandir a quantidade de bots continua aberto. Os benchmarks de alta população precisam ser executados sem a limitação de gameplay.

## Validação

Godot 4.7.2, Windows, JJ7: importação do editor `exit 0`, nenhum erro de parsing/recurso e classe `GameBotPopulation` registrada. `tests/bot_population_limit_11.gd`: **17/17 PASS**, incluindo limites por equipe, redistribuição de humanos e preservação deliberada dos 28 bots nos fixtures. `tests/1102_br_population.gd`: **3/3 PASS**, 22 bots de autoridade BR com um ou dois humanos e roster consistente.

`tests/br_queue_lifecycle_validation.gd` retornou cinco falhas porque o teste pressupõe **12 participantes totais** na fila online, enquanto o próprio código da `main` base `ce2653e` já configura **28 bots online + humanos**, incompatíveis com essa expectativa. A regressão foi identificada e mantida visível; não foi mascarada alterando a política da sala. A comparação dessa regressão com a `main` original deve preceder a homologação integral do ciclo de partida. O escopo QA acima é da política de população, não inclui benchmark de FPS ou uma partida multiplayer remota completa.

**Resultado nesta branch:** implementação e testes unitários da política concluídos, mas **sem integração à main nem publicação** até a conferência final dos fluxos de partida. A investigação de física/poses continua independente.
