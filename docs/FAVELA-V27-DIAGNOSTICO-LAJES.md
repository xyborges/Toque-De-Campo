# Favela V27 — diagnostico de travamento em lajes (09/11/2026)

## Situação
Relato de jogador: ao percorrer algumas lajes na Favela, personagem e camera tremem, bloqueiam movimento ou recuam. Problema persiste na build 97 / 1.13.9 com V26. Esta branch NAO corrige o problema, apenas aumenta a cobertura de QA sem alterar gameplay ou a main.

Base: origin/main no commit ce2653e. Branch: ia/favela-v27-roof-diagnostic-20261109.

## Investigação do codigo
- A V26 eliminou a sobreposicao coplanar do desembarque (antes aproximadamente 0,62 m, depois aproximadamente 0,015 m); os 142 contatos fisicos continuam corretos.
- Caixas d'agua adicionadas pelo decorador `_water_tank` usam `kit.cylinder(..., false)` e nao possuem colisor solido; nao demonstram a causa da travada.
- Os modulos `laje_domestica` e `laje_obra` possuem `CollisionShape3D` de suporte e sao integrados com `solid=true` sobre as lajes acessiveis.
- `GameStepMotion.move` usa `move_and_slide`, testes de degraus e reposicionamento de corpo. O ensaio V26 nao executa toda a cadeia local de `WarPlayer`, camera FPP/TPP e recebimento de rede.

## Testes executados
Godot 4.7.2, JJ7U3G3, 09/11/2026, branch exclusiva. Import do projeto: exit 0.
- Cenário com `WarWorld.build(world,true)`: exit 0, 142 de 142 juntas, maior overlap 0,01502 m; 36 telhados na amostra inicial (180 pontos); ampliacao posterior: 142 telhados, 706 pontos livres e sem interpenetracoes, 24 rotas de transicao, 34 percursos curtos, zero capsulas invadidas, zero recuos, zero bloqueios.
- Mesmo teste com visuais desativados: exit 0 e mesmas metricas. Não foi reproduzida a diferenca alegada entre os dois cenarios.
- Variante `WarPlayer.new()` usando a classe concreta, fisica controlada manualmente em `GameStepMotion.move`, sem processar entrada local ou camera: exit 0, 8 rotas, 12 percursos curtos, zero recuos ou bloqueios. Nao e simulacao integral de jogador humano.
- Logs locais ignorados pelo Git: `work/v27-import.log`, `work/v27-roof-complete.log`, `work/v27-roof-no-visuals.log`, `work/v27-realplayer.log`.

## Veredito
NAO REPRODUZIDO / NAO HOMOLOGADO como correção. A V26 passou ensaios mais amplos, mas o relato humano permanece plausivel. Nao remover colisores de objetos que deveriam oferecer cobertura fisica; nao atribuir a causa aos tanques de agua. Necessario reproduzir com cliente em uma partida real, local e multiplayer, incluindo input e camera FPP/TPP, registrando por frame posicao do corpo, on_floor, normais/objetos das colisões, GameStepMotion e deslocamento/spring-arm da camera. Confrontar em mesma laje com/sem modulos e posicao de partida identica.

Nenhum arquivo de gameplay alterado. Nenhuma release publicada.

- Teste ampliado de todos os acessos: 142/142 lajes inspecionadas, 706 amostras livres, 0 bloqueios nos 24 caminhos percorridos; exit 0, evidencia em work/v27-all-roofs.log.
