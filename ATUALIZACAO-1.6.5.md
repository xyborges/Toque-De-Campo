# Toque de Campo 1.6.5 — câmeras e lançadores de Guerra

## Entrega

Pacote Windows e servidor Linux assinados: build 31, protocolo Guerra 5. Notas visíveis no site e no atualizador. Todos os clientes de Guerra devem atualizar. As partidas continuam com autoridade no Ubuntu; o treino offline usa os mesmos sistemas.

## Causa da piscada FPP

A colisão do SpringArm retraía a câmera corretamente, mas `GamePlayer._update_grenade_pose()`, executado depois, reativava a apresentação FPP ao encontrar `camera_close`. Isso contradizia a perspectiva TPP escolhida. Foi extraída a decisão de apresentação em `_uses_first_person_presentation()`: Guerra usa a seleção explícita de perspectiva/mira. Estar perto de uma parede esconde o corpo que sobrepõe a câmera e não ativa o clone FPP. Apresentações pessoais também ficam ocultas dentro dos blindados. Não foi invertido nenhum eixo do mouse.

Reprodução nativa com parede real e caminhada no mapa Guerra: a exportação publicada 1.6.4 reproduziu o clone FPP após a atualização da animação; a correção não reproduziu. Percurso de cerca de 46 m, 420 quadros, amplitude de rotação horizontal de 435,86 graus. O teste anterior que verificava somente a rotina de colisão não cobria a atualização posterior da apresentação; agora cobre ambas na ordem real.

## Lançadores por equipe

| Equipe | Classe Antitanque | Tecla | Função preservada |
|---|---|---|---|
| 1 — Guarani/Abrams | Stinger | 8 | Aquisição antiaérea contra drone inimigo |
| 2 — BMP-2/T-90 | RPG-7 | 7 | Disparo direto contra blindados |

Implantação, seleção, slots, HUD e execução do disparo validam a exclusividade. Trocar de equipe/classe invalida o lançador anterior. Nenhum jogador recebe os dois.

Os modelos seguem as duas fotografias fornecidas pelo usuário: ogiva, escudo térmico laranja, empunhaduras e luneta lateral no RPG; estrias, colares, mira elevada, eletrônica e unidade bateria/refrigeração no Stinger. Mantida a convenção em metros e eixo -Z para a frente. Geometria rígida agrupada por material; pontos `LauncherMuzzle`, `GripRight` e `GripLeft` preservados no modelo compartilhado FPP/TPP.

Kick de câmera de aproximadamente 6,9 graus no RPG e 5,4 no Stinger, limitado e recuperável, com recuo visual. A física cria o projétil antes do kick. Um evento confirmado duplicado não aplica recuo novamente.

## Blindados e controles

Os quatro veículos compartilham `WarVehicleView` e preservam seus parâmetros de movimento, armamento e balística. Limites e velocidades de torre/elevação são individuais.

- Entrada do operador: óptica fixada à elevação da torre, independente do casco.
- C: óptica ↔ câmera externa, atrás/acima com varredura esférica de colisão.
- Botão direito: zoom persistente 1× → 2× → 4× → 1× na óptica, transição suave de FOV.
- T: visão térmica. X continua como atalho anterior.
- Mouse controla a torre horizontalmente e a elevação vertical; WASD mantém o controle do casco.
- Disparo na saída real do cano. Uma obstrução entre culatra e bocal bloqueia o disparo sem gastar munição.
- Na câmera externa, o indicador projeta a direção efetiva do cano; não converte o tiro em um raio da câmera.
- Passageiro observa com câmera independente, sem escrever o alvo da torre ou obter zoom/armas/térmica do operador.
- Regras existentes de assentos, promoção, saída segura, morte de todos os ocupantes e retorno do veículo após 60 s foram preservadas.

HUD: função, integridade, velocidade, arma, carregador/reserva, recarga, câmera, ampliação, térmica e ângulos. Retículo não sobrepõe menus abertos. A térmica utiliza profundidade e continua bloqueada por paredes/terreno.

## Fumaça

Disparos confirmados apresentam fumaça na origem real; lançadores também possuem saída traseira. É cosmética e não altera velocidade, gravidade ou impulso. O pool existente de 256 instâncias é reutilizado. Eventos são deduplicados e o estado é limpo na troca de operação. Geometria rígida agrupada evita multiplicar nós por detalhe do modelo.

## Validação local

| Cenário | Resultado |
|---|---|
| Comparação nativa TPP 1.6.4 → correção, parede real + andar/olhar | erro reproduzido antes, 6/6 depois; saída normal |
| Lançadores, quatro câmeras, torre/casco, passageiros, obstrução e térmica com parede renderizada | 72/72 nativos |
| Lunetas, mira de sniper, mãos FPP/TPP e saída do cano | 49/49 nativos |
| HUD de classe em 1024×768 e 1920×1080, slots e estoque | 50/50 nativos |
| Guerra: regras, simulação, áudio, implantação e reset | 79/79 |
| Assentos, promoção, saída, destruição, retorno e pacotes antigos | 91/91 |
| Recarga pausada, lançador, veículo, vida e reset | 28/28 |
| Fogo amigo, pontuação e avisos | 19/19 |
| Treino offline com entrada nativa: veículo, drone, granada, AT e retorno ao fuzil | 34/34 |
| ENet: servidor + 3 clientes, RPG e Stinger nas respectivas equipes, tentativa inválida, cura, granada, veículo e combate após desconexão | 27/27 |

Os testes podem usar posições determinísticas/undeployment de diagnóstico para isolar cenários; isso está indicado nos scripts. O teste de caminhada usa o mapa Guerra real e input de mouse injetado no runtime nativo. Os testes centrais usam contas QA reais, TLS e RPCs de produção sem bypass da autoridade. Resultados de publicação são registrados separadamente após ativação.

O teste antigo de HUD pressupunha acesso simultâneo aos dois lançadores. Foi atualizado para a regra nova, incluindo o comportamento existente de clicar novamente no equipamento selecionado para guardá-lo. A implementação não foi enfraquecida para satisfazer essa premissa antiga.

## Desempenho medido

GTX 1650, renderizador Compatibility, 1920×1080; servidor + 12 clientes ENet no mesmo PC, 1 cliente com renderização e 11 sem janela. Cenário invulnerável para manter carga: infantaria atirando, quatro veículos, drones, explosões e desconexão. Monitores `Performance` e uma execução com profiling detalhado do Godot.

| Métrica do cliente visível | Referência histórica 1.6.3 | 1.6.5 sem profiling detalhado |
|---|---:|---:|
| FPS médio | 59.20 | 59.95 |
| 1% low (FPS) | 33.61 | 43.95 |
| Frame médio (ms) | 16.89 | 16.68 |
| Frame P95 (ms) | 19.15 | 18.46 |
| Maior frame (ms) | 36.39 | 32.28 |
| Física média (ms) | 4.64 | 4.74 |
| Memória estática (MiB) | 182.73 | 189.91 |
| Draw calls máximos | 1694.00 | 1710.00 |

Janela da desconexão: 60.07 FPS médios, 1% low 38.35, maior frame 32.28 ms. Máximo de 43 projéteis ativos no cliente e 12 jogadores.

A referência é histórica, não um A/B controlado de otimização; não se atribui a diferença exclusivamente às alterações desta versão. O profiling detalhado registrou 54.88 FPS e picos de 138.11 ms, aproximadamente periódicos durante a coleta. A segunda execução separa esse custo da apresentação normal.

Limitação: o servidor neste ensaio de 13 processos teve pico de 240.27 ms na ativação simultânea dos blindados. A meta de 60 FPS permanentemente estáveis não está comprovada, e este ensaio não substitui 12 PCs separados nem redes reais diversas. Não houve crash nas execuções finais nativas/ENet desta revisão. O fixture isolado de fogo amigo ainda registra aviso de duas instâncias ObjectDB no encerramento, embora suas 19 verificações e a saída do processo passem.

Logs e JSON: `work/war165-movement-comparison.json`, `tests/war165-equipment-results.json`, `tests/war-optics-results.json`, `tests/war-class-hud-results.json`, `work/regression165-results.json`, `tests/war-multiplayer-*.json`, `work/performance165-comparison.json`.

## Arquivos de implementação alterados

- `scripts/player.gd`
- `scripts/ui/infantry_hud.gd`
- `modes/war/scripts/effects.gd`
- `modes/war/scripts/game.gd`
- `modes/war/scripts/launcher_details.gd`
- `modes/war/scripts/launcher_models.gd`
- `modes/war/scripts/player.gd`
- `modes/war/scripts/rules.gd`
- `modes/war/scripts/ui.gd`
- `modes/war/scripts/vehicle.gd`
- `modes/war/scripts/vehicles.gd`
- `modes/war/scripts/vehicle_reticle.gd`
- `modes/war/scripts/vehicle_view.gd`

Publicação e notas: `distribution/release-notes.json`; inspeção do pacote: `work/inspect_published_pack.gd`. Testes novos/atualizados ficam em `tests/` e não integram a distribuição de produção.

## Publicação concluída e verificação central

Ativada no Ubuntu em `/opt/toque-de-campo/releases/build-31`; Naval, Deserto e Guerra ativos. Site e launcher apresentam 1.6.5 com estas notas. Download real validado por assinatura/hash, instalação concluída; segunda execução confirmou que não há novo download. O PCK real inclui os recursos novos e não inclui a cena QA.

A própria exportação Windows passou as seis verificações de parede, caminhada e rotação, em janela nativa fora da árvore das fontes, com saída normal do processo.

Sete etapas pós-publicação passaram:

- Distribuição, instalação, assinatura e ausência de download repetido.
- Lançadores: 15 verificações com duas contas reais, implantação de AT opostos, seleção inválida recusada, tiro RPG aceito, evento visual remoto e Stinger sem lock preservando suas cargas.
- Respawn: 19 verificações; pavio medido 5,023 s e implantação após 4,039 s; estado da próxima vida e persistência de morte confirmados.
- Passageiros: 33 verificações com três contas reais, incluindo tentativa de controle indevido, promoção e saída segura.
- Deserto: duas contas carregadas, disparo e replicação em ambos os clientes.
- Naval: movimento/disparo, recebimento remoto de projétil e áudio, partida continuando após saída do criador.
- Ranking: 11 verificações de esquema/cache e recusa de ações privilegiadas com credenciais comuns.

Relatórios: `tests/release165-postpublication.json`, `tests/release165-final-status.json`, `tests/ubuntu-war-launchers-*.json`, `tests/ubuntu-war-respawn-*.json`, `tests/ubuntu-war-passengers-*.json`. Os logs de publicação ficam em `work/release165-*.log`. Toda a coordenação usa contas QA; nenhuma mensagem foi enviada a outros jogadores.
