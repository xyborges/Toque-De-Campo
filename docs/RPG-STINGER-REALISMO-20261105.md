# RPG-7 e FIM-92 Stinger — detalhamento visual e lançamento

Implementação isolada em `ia/rpg-stinger-realismo`, iniciada em 05/11/2026. **Não integrar à main nem publicar automaticamente.**

## Modelo de RPG-7
- Geometria existente preservada: tubo, tubo traseiro aberto, escudos, ogiva, gatilho e encaixes das mãos.
- PGO-7 fixa no lado esquerdo com sapata de montagem, parafusos, ocular de borracha, anel de foco, torre de ajuste com graduação e controle de iluminação.
- Retícula de lançador exclusiva baseada em referências de escalas de mira (sem alterações de FOV ou sensibilidade do jogo).
- Nenhum soquete universal de acessórios: `rpg.tres` segue sem encaixes e as ópticas adicionais são rejeitadas.

## Modelo de Stinger
- Componentes de gripstock, bateria/coolant, trava, unidade IFF e apoio óptico/seletor.
- Retícula circular própria no shader de luneta e indicação de lock já exibida no HUD.
- Áudio local (sintetizado em PCM, sem arquivo externo): tom inicial de aquisição, pulsos progressivos durante rastreio, confirmação dupla e pulso constante após lock.
- A autoridade continua validando os travamentos e o consumo das cargas no servidor; som não é enviado via RPC.

## Lançamento e percurso
- Os dois projéteis continuam surgindo em `LauncherMuzzle` e seguindo a integração de física/varredura de colisão vigente.
- Geometrias 3D próprias de baixo custo, com corpo afunilado, cauda e aletas (pools MultiMesh por modelo).
- Rastros visuais já existentes mantidos, reforçados por pequenas emissões de fumaça por tempo de voo e pluma na boca do tubo/backblast.
- Sem alterar velocidade, dano, raio de explosão, gravidade ou curva de perseguição: preservação de balanceamento e replicação multiplayer.

## Verificação exigida antes da integração
- Importação e parse no Godot 4.7.2.
- `tests/launcher_realism_qa.gd`: **32/32 PASS** no Godot 4.7.2, incluindo modelos, ópticas exclusivas, tons, malhas e disparo RPG/Stinger autoritativo (trava + consumo + origem exata do cano).
- `tests/war_optics.gd` e `tests/offline193_launcher.gd` para câmera, equipar e disparo autoritativo.
- Revisão visual FPP/TPP e verificação de desempenho em combate real no integrador.

**Nota:** A lógica preexistente de Stinger identifica drones e blindados inimigos, conforme a mecânica do jogo. Esta entrega não remove alvos terrestres nem transforma sua simulação em instruções de operação de armamento real.
