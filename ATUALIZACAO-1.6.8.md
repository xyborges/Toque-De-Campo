# Atualização 1.6.8 — blindados, mira e míssil TV

Segunda etapa da solicitação. A 1.6.7/build33 foi publicada primeiro com as correções de fumaça, térmica e sniper. Esta entrega preserva essas correções e a câmera TPP da 1.6.6. O protocolo Guerra passa a7; todos os jogadores devem atualizar.

## Controles e comportamento

- Configurações → Sensibilidade: 28 perfis locais, com sensibilidade normal e multiplicador de mira/zoom. Inclui armas de infantaria, granada, blindados, drone, armas dos blindados, navios e armamento naval. Os multiplicadores de veículo e armamento se combinam; os padrões mantêm os controles anteriores. Dados finitos, limites de5% a300%, salvamento agrupado e persistência fora da pasta da versão.
- Q alterna principal/secundária nos quatro blindados. R recarrega o armamento selecionado. Não restaura munição ou temporizadores ao trocar.
- Abrams/T-90: coaxial com80 tiros no carregador,400 de reserva, recarga4s e intervalo.10s. Canhão e coaxial têm estados independentes: a metralhadora funciona enquanto o canhão recarrega.
- Guarani/BMP-2: secundário MÍSSIL TV,1 carregado e5 de reserva, recarga/cadência12s. Lançamento no Marker3D do tubo visível. Um projétil ativo por APC.
- A câmera fica no míssil real. O mouse comanda uma direção desejada; o servidor limita o giro a1.35rad/s. C abandona o link e retorna à óptica; o míssil continua balístico. F conserva o procedimento de saída segura do veículo. Térmica não funciona no míssil.
- Enquanto guia, o operador mantém seu assento. O servidor retira aceleração, direção e disparos do casco, que desacelera normalmente, e preserva o alvo da torre. Passageiros não recebem armas, câmera do míssil ou controle do veículo.
- Impacto, fim do voo, morte, saída, desconexão, troca de ocupação e reset encerram a guia/câmera sem criar operador fantasma. Perda de comandos por.65s rompe o link. O cliente não pode reativar um link abandonado.
- Estados do míssil a10Hz com sequência e reconciliação visual. Entrada recente recebe posição/velocidade atuais do míssil. Colisão, explosão, dano, munição e autoridade continuam no servidor; o offline usa os mesmos sistemas.

## Balanceamento

| Armamento | Antes | Depois |
|---|---|---|
| Abrams | dano550, raio9m, gravidade12 | dano600, raio11m, gravidade17 |
| T-90 | dano520, raio9m, gravidade12 | dano570, raio10.5m, gravidade17 |
| BMP-2 30mm | raio2.8m, gravidade9.81 | raio3.2m, gravidade11 |
| Míssil TV dos APCs | inexistente | dano320, raio4.5m, velocidade115m/s, alcance1000m, vida8.5s |

A .50 do Guarani permanece de impacto direto; seu novo míssil oferece a opção de dano em área. Explosões preservam bloqueio por obstáculos, queda de dano por distância e regras de fogo amigo. A sniper da1.6.7 permanece com alcance2200m, velocidade620m/s, gravidade12 e arrasto.008. O ciclo COMPLETO de dia/noite permanece480segundos, conforme resposta do usuário.

## Som e óptica

Doze loops de síntese original, com timbres distintos de motor/rolagem/servo para Guarani, BMP-2, Abrams e T-90. Não são gravações autênticas dos veículos. Rolagem silencia parado; motor varia com velocidade; servo responde a yaw e pitch. Três fontes3D por veículo, reaproveitadas, com limites de distância. PCM mono22050Hz,2s, pico dos arquivos.70.

A óptica FPP do operador utiliza moldura discreta de sensor, dados de azimute/elevação e modo EO/FLIR. O míssil mostra link, tempo, distância e comando de retorno. Sem geometria opaca cobrindo o campo central. Armas na cabine passam por filtro1800Hz e atenuação6dB, enviadas uma única vez ao limiter compartilhado. Veículos usam1600Hz e3dB adicionais dentro da óptica. Externa remove esse tratamento extra; passageiros mantêm o comportamento interior anterior. O ouvinte3D acompanha o míssil e retorna ao personagem ao sair.

## Referências

A opção escolhida pelo usuário foi câmera embarcada, não um TOW guiado pela óptica. A referência consultada foi o G-84 TGM de Lis, descrito oficialmente pela EA como míssil TV guiado pelo jogador: [Welcome to Zero Hour](https://www.ea.com/games/battlefield/news/battlefield-briefing-welcome-to-zero-hour). Também foram consultadas as [notas oficiais de veículos](https://www.ea.com/games/battlefield/battlefield-2042/news/dev-notes-state-of-vehicle-gameplay) e [Update6.2](https://www.ea.com/en-gb/games/battlefield/news/battlefield-2042-update-notes-6-2). A implementação usa os sistemas e a autoridade do Toque de Campo, sem código ou recursos extraídos de Battlefield.

## Validação local concluída

- Sensibilidade38/38:28 perfis, aplicação real em look/zoom, configuração em partida, persistência e rejeição de valores inválidos.
- Míssil/armamento53/53: quatro veículos, saída pelo marker real, recargas independentes, munição finita, retorno de câmera, morte/reset/respawn e limite de giro.
- TV ENet17/17 com servidor e três clientes, operador em janela nativa: direção do mouse aplicada pelo servidor, observador recebendo estados/impacto, comandos de passageiro rejeitados e link encerrado na perda de controles.
- Áudio45/45:12 arquivos PCM distintos, amostras reais do mixer audíveis sem clipping, servo vertical, rolagem, roteamento FPP/externo/passageiro e orçamento de fontes. Picos medidos dos loops.044–.131 no cenário, sem saturação.
- Transporte91/91 e rede de passageiros24/24: assentos, promoção, saída bloqueada/segura, destruição de todos ocupantes e respawn.
- Regressões: equipamento/térmica80, ópticas49, HUD50, sniper18, combate48, ENet27. Resultados em tests/release168-regressions.json.

## Desempenho e publicação

GTX1650,1920×1080 reais em fullscreen,12 clientes ENet mais servidor no MESMO PC (13 processos),25s úteis após aquecimento. Combate de infantaria,4 veículos,2 drones, explosões e desconexão. Os arquivos brutos e a comparação estão em `tests/performance168-comparison.json`.

| Exportação | FPS médio | 1% low | Frame médio | P95 | Pico | Janela de desconexão |
|---|---:|---:|---:|---:|---:|---:|
|1.6.7 sem gravação do Profiler |57.79|34.82|17.303ms|22.293ms|32.932ms|58.58FPS / pico27.918ms|
|1.6.8 sem gravação do Profiler |57.85|34.31|17.286ms|21.397ms|34.910ms|58.55FPS / pico28.297ms|
|1.6.7 com Profiler |48.20|6.21|20.748ms|29.399ms|198.644ms|48.24FPS|
|1.6.8 com Profiler |47.13|5.95|21.216ms|32.538ms|189.040ms|43.83FPS|

Sem gravação contínua do Profiler, não houve frame acima de50ms nas duas exportações. Os dados com Profiler incluem o custo da instrumentação/impressão periódica e não devem ser apresentados como FPS do executável normal. A rodada intermediária da fonte teve39.42FPS com picos853ms, ficou preservada como diagnóstico e motivou a repetição comparável entre PCKs; não foi ocultada nem usada para alegar melhoria. A comparação final mostra custo médio praticamente igual, não ganho garantido de desempenho.

A meta de60FPS estáveis/1%low60 NÃO foi atingida neste ensaio de13 processos. Isso também não representa12PCs distintos. Não houve crash ou erro de script. A redução do custo da fumaça permanece documentada separadamente na1.6.7, com medições normal/térmica antes/depois.

Pacote build34 inspecionado em diretório isolado: recursos novos presentes, entrada normal do jogo e cena QA ausente. Câmera TPP exportada8/8,420frames,435° de giro horizontal,0frames com FPP/entrada na cabeça. Colisão real TV com parede3/3: impacto físico encerra guia e protege o personagem atrás da cobertura. Publicação concluída no Ubuntu:1.6.8/build34, protocolo Guerra7. Três serviços ativos, apontando para build34. Download real, assinatura/hash, instalação, ausência de download repetido e boot normal verificados. Teste de produção TV25/25, com três contas reais e sem bypass de autoridade: guia, snapshots, cancelamento, passageiros, promoção/saída e ausência de reserva fantasma. Deserto com duas contas reais: disparos e granadas cozidas replicados. Naval também passou no transporte local com20–65ms e101 datagramas descartados. Estado final em tests/release168-final-status.json.

## Arquivos principais

scripts/aim_sensitivity.gd, scripts/ui/aim_settings.gd, scripts/player.gd, scripts/main.gd, scripts/ui/main_menu_options.gd; modos Naval (câmera/configurações); modes/war/scripts/{game,ui,vehicles,vehicle,vehicle_models,vehicle_reticle,projectiles,tv_guidance,rules,soundscape,effects}.gd; scripts/weapon_audio.gd; audio/war/{engine,rolling,servo}-*.wav; distribution/release-notes.json. A versão Three/Babylon de referência não foi alterada.
