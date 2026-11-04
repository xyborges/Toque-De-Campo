# Toque de Campo — atualização 1.7.0

Publicada no Ubuntu `192.168.101.24`, build **38**. Site, instalador, atualizador e os três serviços utilizam a mesma versão. As correções de combate foram publicadas primeiro na **1.6.10, build 37**, antes desta etapa de menus e implantação. Referências Three.js/Babylon preservadas.

## Interface e implantação

- Loadout antes do primeiro spawn e do respawn no Offline e no PVP Deserto. No Guerra, a tela reúne equipe, classe, equipamento, prévia do personagem e ponto de entrada.
- Armas, granadas e equipamentos removidos da seleção também saem do inventário, munição, atalhos e HUD daquela vida. Não existem slots fictícios para classes incompatíveis.
- O servidor verifica equipe, classe, escolhas e ponto de entrada; o cliente não escolhe sua própria quantidade de munição. Alterar a seleção de um personagem vivo prepara a próxima vida e não substitui o equipamento atual.
- O Naval exige confirmação da embarcação. O dono só inicia com pelo menos dois participantes e todos prontos. Após morrer, o jogador confirma uma nova implantação, respeitando o intervalo do servidor.
- A troca de embarcação durante a vida continua sujeita a integridade completa e 10 segundos sem dano.
- Pausa compartilhada: continuar, configurações, controles, placar, equipamento/frota e saída com confirmação. Offline pausa a simulação; multiplayer permanece ativo.
- Configurações reais de vídeo, áudio, sensibilidade, controles e interface. Naval não apresenta opções de infantaria sem função. Alterações de tela precisam de confirmação em 10 segundos ou são revertidas; janela e tela cheia foram verificadas nativamente.
- Nomes curtos e ícones nas telas revisadas. Removidas explicações de exclusividade, mensagens rotineiras de sincronização e textos sobre validações internas. Estatísticas detalhadas das armas aparecem no painel secundário ao selecionar.
- Paleta, tema e componentes existentes foram reutilizados. A diretriz foi registrada em `DIRETRIZES-INTERFACE.md`.

As preferências de loadout são gravadas neste PC por conta, modo e, no Guerra, equipe/classe. Opções de áudio e controles também são locais e usam a pasta persistente já fornecida pelo atualizador. Compras, saldo, frota e perfil de conta continuam no serviço central. Esta versão não implementa sincronização de preferências de loadout entre computadores.

## Correções da 1.6.10 incluídas

| Sistema | Resultado |
|---|---|
| Guarani | Autocanhão 30 mm no lugar da .50; cano, munição e HUD ajustados. |
| Guarani/BMP-2 | Velocidade inicial de 405 m/s, gravidade 12, arrasto 0,018 e dispersão angular de 0,10°. Explosões de 2,8 m e 3,2 m, respectivamente. |
| Abrams/T-90 | Projéteis 15% mais lentos: 484,5 m/s e 476 m/s. Mantida a queda já configurada. |
| Dano de explosões | Exposição de diferentes partes do corpo, proteção por paredes, confirmação de dano em veículos e proteção contra crédito duplicado. |
| Térmica | Alcance visual ampliado; assinatura de veículos além do antigo corte. Câmera TV herda o sensor ativo; T pode alterná-lo. Câmera externa continua normal. |
| Armas de veículos | 1 seleciona a principal; 2, a secundária. 3/4 não criam armas inexistentes. HUD mostra as armas reais e sua munição. |
| Áudio | Ambiente menos intrusivo e controles separados para geral, música, efeitos, armas, ambiente, veículos, passos e interface. Volume anterior da música é migrado uma única vez. |

As causas verificadas incluíam corte da assinatura térmica a 650 m, LOD de veículos terminando a 950 m, desativação explícita do sensor ao entrar na câmera TV e ausência de confirmação de dano no caminho de dano de veículos. A explosão usava uma avaliação de exposição insuficiente para certos contatos com o corpo. No teste a aproximadamente 850 m, o disparo real de tanque matou o alvo, registrou um abate e confirmou seus 100 pontos de dano; repetir o evento não deu outro abate.

## Arquivos principais

Novos componentes compartilhados:

- `scripts/loadouts.gd`: regras de slots, validação, aplicação e persistência.
- `scripts/options.gd`: opções reais de renderização, janela, controles e interface.
- `scripts/ui/loadout_editor.gd` e `scripts/ui/infantry_deployment.gd`: editor e implantação.
- `scripts/ui/settings_panel.gd` e `scripts/ui/pause_menu.gd`: configurações e pausa.
- `scripts/audio_settings.gd` e `scripts/ui/audio_settings.gd`: buses e volumes compartilhados, introduzidos na etapa de correções e preservados nesta etapa.

Integrações:

- `scripts/main.gd`, `scripts/player.gd`, `scripts/inventory_slots.gd`, `scripts/desert_domination.gd`: ciclo de vida, implantação, inventário e reabastecimento dos itens realmente selecionados.
- `scripts/ui_focus.gd`, `scripts/ui/scoreboard.gd`, `scripts/ui/main_menu.gd`, `scripts/ui/menu_page.gd`, `scripts/ui/infantry_hud.gd`, `scripts/ui/naval_hud.gd`, `scripts/ui/aim_settings.gd`, `scripts/ui/ui_feedback.gd`, `scripts/ui/ui_kit.gd`: navegação, textos, foco, HUD e componentes.
- `modes/war/scripts/game.gd`, `player.gd`, `ui.gd`, `rules.gd`, `vehicles.gd`: implantação validada, equipe/classe, assentos, equipamentos e correções de combate.
- `modes/naval/scripts/network.gd`, `match.gd`, `mode.gd`, `catalog.gd`: prontidão, implantação, respawn e navegação naval.
- `scripts/damage_numbers.gd`: respeita a opção de indicadores de dano.
- `distribution/release-notes.json`: novidades incluídas no site e no instalador.

## Validação realizada

| Teste | Resultado |
|---|---|
| Offline: pré-spawn, seleção por vida, pausa, janela/tela cheia, controles e persistência | 30 verificações, sem falhas. |
| Guerra offline, com 11 bots | 15 verificações: equipe/classe, slots opcionais, respawn e persistência. |
| Lobby/implantação naval nativa | 13 verificações: prontidão, espera, respawn e preservação das configurações abertas. |
| Deserto ENet, servidor e dois clientes separados | 20 verificações: rejeição de loadouts forjados, escolhas diferentes, cooldown, implantação e limpeza de estado. |
| Guerra multiplayer | 27 verificações de combate, granadas e projéteis de veículos. |
| Passageiros/operador em rede | 24 verificações de assentos, autoridade e saída. |
| Naval com proxy de rede | Sem falhas nos três papéis, com 5% de perda e atraso entre 20–65 ms. |
| Correções de combate/térmica/áudio | 25 verificações; inclui tiro de tanque a 850 m e pixels da térmica a 1.200 m com oclusão por parede. |
| Regressões de sensibilidade, TV, equipamento, ópticas, HUD de classe, sniper e combate | 37, 53, 80, 49, 50, 18 e 48 verificações, respectivamente, sem falhas na rodada final. |
| TPP no PCK exportado | 420 quadros, cerca de 46 m percorridos e mais de 435° de giro acumulado; zero quadros com a apresentação FPP aparecendo sobre a TPP. Colisão da câmera testada com parede real. |
| Menus no PCK exportado | 8 verificações: implantação, arma FPP/TPP, placar, TAB após pausa, configurações e saída. |
| Produção Ubuntu — Guerra | 3 contas reais, 25 verificações: implantação balanceada, TV, controle do operador e passageiro sem autoridade indevida. |
| Produção Ubuntu — Naval | 2 contas reais, 10 verificações: frota, prontidão, partida, disparos iguais nos dois clientes, liberação do gatilho e saída. |
| Produção Ubuntu — Deserto | 2 contas reais; implantação, disparo autoritativo, corpo remoto e granada preparada/lançada/explodida, sem falhas. |
| Distribuição real | Download idêntico ao assinado, instalação da 1.7.0 pelo atualizador, segunda execução sem baixar novamente, recursos do PCK presentes e boot do executável release sem erros registrados. |

Fixtures antigas que presumiam respawn imediato ou granada em todas as classes foram adaptadas às novas regras. O histórico inicial foi preservado em `tests/release170-regressions-history.json`; a rodada final está em `tests/release170-regressions.json` e o estado agregado em `tests/release170-final-status.json`.

A inspeção visual pela ferramenta Computer Use não avançou porque sua autorização expirou. Não foi contada como teste aprovado. A conferência visual nativa usou capturas do renderizador e o PCK exportado carregado pelo executável Godot de desenvolvimento. Uma tentativa de executar um script externo diretamente no .exe release excedeu 35 segundos e também não foi contada como teste de interface aprovado; o boot normal do release e a instalação real foram verificados separadamente.

## Desempenho medido

GTX 1650, 1920 × 1080, limite de 60 FPS, servidor local e 12 clientes reais no mesmo PC. Janela medida de cerca de 25 segundos, com disparos, veículos, drones, explosões e uma desconexão. Fixture de invulnerabilidade mantém os participantes atirando. Métricas coletadas no Godot e por tempo de quadro; não é uma medição de 12 computadores humanos nem de latência de internet.

| Métrica do cliente renderizado | 1.6.10 | 1.7.0 |
|---|---:|---:|
| FPS médio | 60,02 | 59,47 |
| 1% low | 45,25 | 35,55 |
| Tempo médio do quadro | 16,66 ms | 16,82 ms |
| P95 | 18,64 ms | 19,63 ms |
| Maior quadro | 27,66 ms | 53,51 ms |
| Pico de memória monitorada | 217,81 MiB | 227,36 MiB |
| FPS médio na janela de desconexão | 60,08 | 60,10 |
| Maior quadro na janela de desconexão | 27,66 ms | 30,77 ms |

Não há garantia de 60 FPS estáveis: houve um pico de 53,51 ms e o 1% low piorou nesta amostra. A atualização não é apresentada como uma otimização de desempenho. Relatórios completos: `tests/benchmark170-before170-noprof.json` e `tests/benchmark170-after170-noprof.json`.

## Instalação e compatibilidade

Abra o atualizador existente ou baixe em **http://192.168.101.24/**. Novidades constam no site e no instalador. Acesso exige rede/rota/VPN até a VM.

Todos devem atualizar: Guerra usa protocolo 10; Naval, 5; implantação do Deserto, 1. Os três serviços foram verificados ativos após a publicação. A ativação utilizou o publicador aprovado com guarda de salas vazias; partidas ocupadas não foram forçadas a reiniciar.
