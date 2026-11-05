# Inspeção visual — RPG-7 e FIM-92 Stinger
Data: 05/11/2026 | Branch: `ia/rpg-stinger-realismo`

## Método
O Godot 4.7.2 renderizou a cena de teste integrada `tests/war_optics_fixture.gd` em janela real de 1280 × 720, com HUD do Modo Guerra, personagem, câmeras FPP/TPP, retículas no ADS e projéteis dinâmicos em `WarProjectiles`. Script repetível: `tests/launcher_visual_review.gd`. Todas as oito capturas de PNG retornaram `OK` e o processo terminou com código 0.

Evidência local: `work/launcher-visual/overview.png` (montagem de 8 imagens). Individuais: `rpg-tpp.png`, `rpg-fpp.png`, `rpg-ads.png`, `rpg-projectile.png`, `stinger-tpp.png`, `stinger-fpp.png`, `stinger-ads.png`, `stinger-projectile.png` na mesma pasta. Imagens geradas em `work/` são ignoradas pelo Git, sem sobrescrever capturas antigas de outras worktrees.

## Achados e correções
1. **RPG-7:** FPP e TPP usam modelo reconhecível, mão/arma preservadas, sem objetos brancos ou partes soltas aparentes. A PGO-7 apresenta retícula própria; ocular traseira antes opaca ganhou lente colorida e aro. ADS confirmado em 26°.
2. **Stinger:** o conjunto de eletrônica e mira encobria muito da tela à direita no FPP. A apresentação local foi afastada e abaixada, sem alterar o encaixe de terceira pessoa, marcadores físicos nem saída do projétil. ADS circular exclusivo confirmado em 35°.
3. **HUD Guerra:** seleção do equipamento ainda dizia `JAVELIN`. Corrigido para `STINGER` em `scripts/ui/infantry_hud.gd`. Os nomes históricos de munição `javelin` do modo Battle Royale **não foram alterados**, pois pertencem a outro domínio.
4. **Foguetes:** o primeiro enquadramento incluía o tubo do lançador, escondendo o míssil. A câmera da auditoria foi posicionada após a saída da boca do cano, escondendo personagem e arma apenas na captura. Ambos os projéteis exibem corpo, ponta, aletas e pluma. Aletas reduzidas levemente em `projectiles.gd` para proporção mais plausível.
5. **Comparação TPP/FPP:** não há evidência visível de geometria flutuando nos oito enquadramentos. O deslocamento do modelo da Stinger é exclusivo da apresentação FPP.

## Validação
- Godot 4.7.2, janela 1280 × 720, renderizações TPP/FPP/ADS/projétil: **8/8 imagens geradas, sem erros de script**.
- `tests/launcher_realism_qa.gd`: **32/32 PASS**, status 0 após os ajustes de proporção e pose.
- FOV conferido durante captura: RPG 26°, Stinger 35°.
- Nomes e retículas exclusivos preservados; lógica de dano, autoridade, trava e trajetória não foi alterada nesta inspeção.
- `git diff --check` e hook pre-commit deverão passar antes de integração.

## Limites e pendências
A auditoria foi feita em cena de teste com fundo neutro; não substitui uma sessão de jogo em mapa completo com movimento, oclusão de obstáculos e multiplayer com dois clientes. Som de lock foi verificado anteriormente por geração PCM/código, mas não houve avaliação perceptiva com fones nesta inspeção. A pluma permanece estilizada e pode parecer clara em fundos cinzentos; revisar aparência também nos mapas reais e ao longe. A auditoria não publica nem integra a `main`.
