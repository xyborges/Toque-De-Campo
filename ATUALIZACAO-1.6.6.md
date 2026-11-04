# Toque de Campo 1.6.6 — correção da piscada TPP em Guerra

## O que foi reproduzido

O usuário confirmou que braços/arma grandes apareciam sobre a tela durante movimento em TPP. O erro foi reproduzido no pacote publicado 1.6.5/build 31, em terreno aberto no mapa Guerra, com caminhada e movimento contínuo do mouse. Foi capturado um quadro real após `RenderingServer.frame_post_draw`: `work/war166-camera-flash-166-before-capture.png`.

A perspectiva escolhida continuava TPP e o clone FPP estava oculto. Mesmo assim, a câmera voltava momentaneamente ao ponto do ombro, expondo a própria arma e braços do modelo no mundo. O teste antigo verificava apenas se o clone FPP estava visível; por isso passava enquanto o problema de posição continuava.

## Causa no código

`GamePlayer.apply_look()` chama `_update_camera_collision(0)` ao receber movimento do mouse. Em Guerra, essa função executava `camera.position = Vector3.ZERO` também em TPP, apagando a distância Z que o SpringArm acabara de resolver. O braço só reposicionava a câmera no próximo passo de física. Entre o input e esse próximo passo, um quadro podia ser desenhado no ombro em vez de atrás do personagem.

A atualização da apresentação base também escrevia um offset próprio da câmera, sem preservar o que o SpringArm tinha calculado. Na renderização, isso aparecia como um flash de primeira pessoa mesmo sem mudar `third_person` nem ativar o clone FPP.

O comportamento do SpringArm está descrito na [documentação oficial](https://docs.godotengine.org/en/stable/classes/class_springarm3d.html): ele move seus filhos diretos ao longo do eixo Z até a distância livre de colisão. O código do jogador estava sobrescrevendo essa posição entre os passos da física.

## Correção

Arquivo de produção: `modes/war/scripts/player.gd`.

- Removida a atribuição de posição zero da atualização TPP, incluindo chamadas vindas do mouse.
- Preservado o offset resolvido ao executar a atualização herdada da apresentação.
- O SpringArm passa a iniciar com a distância configurada pelo jogador.
- Ao entrar voluntariamente em TPP, a câmera recebe uma posição inicial segura por varredura esférica; depois o SpringArm controla a translação.
- A ocultação por proximidade usa a posição real da câmera; a distância deixa de ser zerada para fingir colisão.
- Mantidos controles, sensibilidade, zoom, mira, balística, hitboxes, regras de combate e multiplayer.

Nenhuma coleta de quadros ou telemetria de teste foi adicionada ao jogo de produção. Os observadores de renderização ficam exclusivamente nos testes.

## Verificação por quadro

O teste novo registra a posição da câmera em `RenderingServer.frame_pre_draw`, imediatamente antes do desenho. Verifica distância real, distância resolvida, perspectiva e visibilidade do clone. Durante o percurso também força oito atualizações de apresentação para cobrir o segundo caminho de escrita.

São limites de FPS configurados no teste, não uma afirmação de que o hardware sustentou exatamente cada taxa.

| Pacote/código | Limite de FPS | Quadros de salto ao ombro com distância livre | Maior erro frente à solução do SpringArm | Resultado |
|---|---:|---:|---:|---|
| 1.6.5 publicado | 144 | 182 | 3.249999 m | reproduzido |
| 1.6.6 correção | 30 | 0 | 0.000122 m | 8/8 |
| 1.6.6 correção | 60 | 0 | 0.000122 m | 8/8 |
| 1.6.6 correção | 144 | 0 | 0.000122 m | 8/8 |
| 1.6.6 correção | 240 | 0 | 0.000122 m | 8/8 |

Cada execução cobre 420 quadros de movimento e mais de uma volta horizontal. O máximo erro residual após a correção foi cerca de 0,12 mm de arredondamento em coordenadas do mapa. Foram usados colisores reais na checagem de parede; a câmera continua recolhendo diante de obstáculo.

## Teste online real

Duas contas QA autenticadas com TLS no Ubuntu 192.168.101.24, usando implantação e movimentação normais, sem modo de teste nem teleporte privilegiado. Cliente nativo caminhou, moveu o mouse e trocou pistola/FAL durante 420 quadros monitorados. Zero saltos ao ombro, zero clone FPP e erro máximo de aproximadamente 0,061 mm. O observador continuou vendo o personagem remoto.

Relatórios: `tests/ubuntu-war-camera-host.json`, `tests/ubuntu-war-camera-guest.json` e `tests/war166-camera-matrix-results.json`.

## Regressões

- 49 verificações nativas de miras, mãos e saída do cano.
- 50 verificações nativas do HUD de classes em duas resoluções.
- 72 verificações nativas dos lançadores, quatro câmeras dos blindados, passageiros, colisão, bloqueio do cano e térmica.
- A primeira leitura de pixels do teste térmico usava um framebuffer anterior. O fixture foi corrigido para aguardar `frame_post_draw`, sem alterar o shader ou a regra do jogo. Na repetição, luminância coberta 0,024 e exposta 0,875, com as mesmas exigências de contraste; 72/72 passaram. O resultado inicial permanece registrado.

## Arquivos

- Implementação: `modes/war/scripts/player.gd`.
- Notas no site/atualizador: `distribution/release-notes.json`.
- Testes: `tests/war166_camera_probe.gd`, `tests/ubuntu_war_camera.gd`, `tests/run_ubuntu_war_camera.py` e espera de renderização em `tests/war165_equipment.gd`.
- Evidências completas: `work/war165-movement-166-*.json`, com amostras por quadro, e `tests/war166-regressions.json`.

## Distribuição

Versão publicada 1.6.6/build 32, protocolo Guerra 5 mantido. Exportação, ativação, download e testes centrais concluídos. O atualizador precisa ser executado em cada PC para receber o código local de câmera corrigido.


### Resultado final da publicação

- PCK Windows real fora das fontes: 8/8, zero quadros com salto ao ombro e zero clone FPP.
- Ubuntu: build 32 ativo, com os três serviços funcionando e notas 1.6.6 no site.
- Download assinado e instalação real: verificados; segunda execução não baixou novamente.
- Câmera online após publicação: 9 verificações entre duas contas, incluindo 420 quadros de movimento do cliente nativo sem saltos/clone FPP.
- Respawn central após publicação: 19/19, mantendo autoridade e preferências de implantação.

Relatórios finais: `tests/release166-validation.json` e `tests/release166-final-status.json`. Protocolo 5 preservado; cada PC precisa atualizar pelo launcher para carregar a correção local da câmera.
