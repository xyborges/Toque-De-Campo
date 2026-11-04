# G3 — integração modo Guerra (03/11/2026)

## Escopo
- G3 clássico com coronha, empunhadura e guarda-mão verdes; geometria procedural original e materiais/malhas compartilhados.
- Exclusivo do lado de índice 1: Rússia (Ucrânia) e Mujahidins (Afeganistão).
- Substitui a AK como primária padrão do lado de índice 1, sem remover a AK dos outros modos.
- Não foi incluído no loot, loja ou inventário do Battle Royale.

## Mecânicas
- ID g3, primária, automática, 20 cartuchos, reserva 120, 60 de dano, velocidade 785 m/s, arrasto 0.08, recarga 3.1 s, cadência 0.13 s, recuo 0.030.
- Utiliza o pipeline de disparo, predição e validação autoritativa já existente.
- Modelo com Muzzle e marcadores de mãos; animação de recarga usa a lógica de FAL, com magazine e charging handle móveis.
- Traçantes e fumaça seguem o orçamento de efeitos já existente.
- Usa áudio do usuário próximo e distante: audio/g3_near.mp3 e audio/g3_far.mp3, trocando amostra a partir de 160 metros.

## Validações
- Importação e parse do Godot 4.7.2 headless.
- tests/g3_validation_20261103.gd verifica catálogo, balística, munição, modelo, áudio, loadout e restrição adversária.
- Teste visual e partida online com dois clientes ainda são recomendados antes de publicação.

## Observação
- Pastas de mapa e projeto de desempenho não foram editadas.
