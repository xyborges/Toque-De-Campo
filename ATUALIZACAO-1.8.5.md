# Toque de Campo 1.8.5 — AK e FAL

A arma de madeira que estava identificada como FAL passa a se chamar **AK**, incluindo identificação interna, modelo, arsenal, loja, loadouts, HUD, sensibilidade, som, munição e eventos de combate. Seu carregador de 30 tiros, reserva de 180 e comportamento automático foram preservados.

A **FAL** é uma arma separada, com 20 tiros, reserva de 120, recarga de 6 s, disparo automático e som `sound_098.wav` fornecido pelo usuário. Seus parâmetros de jogo têm dano de 62, cadência de 0,13 s e velocidade inicial de 300 m/s. São valores de balanceamento do jogo, não uma simulação das especificações de uma arma real.

## Disponibilidade

- Guerra, Equipe 1: FAL para as classes com fuzil.
- Guerra, Equipe 2: AK para as classes com fuzil.
- Atirador: permanece com a sniper.
- Offline Escritório, Offline Deserto e PVP Deserto: AK e FAL aparecem como opções de arma principal. As regras de propriedade e seleção continuam em vigor.
- O Naval continua com armamento de embarcações.

O servidor verifica a equipe, classe e loadout antes de implantar/equipar. Clientes antigos precisam atualizar: protocolo de loadout 5 e Guerra 17.

## Modelo e mira

O modelo original em `scripts/fal_model.gd` foi construído a partir da silhueta do FAL padrão: coronha fixa chanfrada, guarda-mão longo com respiros, carregador reto, tubo de gases, regulador, alça de transporte, seletor, alavanca de manejo, guarda-mato aberto e quebra-chamas com abertura real.

A mira de ferro é geometria 3D: abertura traseira e poste frontal alinhados. O marcador de saída do projétil é filho do modelo, na extremidade do cano, acompanhando seu movimento. A apresentação em primeira pessoa utiliza a mesma geometria da arma no mundo. As superfícies rígidas são agrupadas em quatro malhas por acabamento, compartilhadas entre instâncias.

Na primeira inspeção visual, algumas partes ficaram ausentes porque a combinação de superfícies indexadas e não indexadas deixava triângulos de fora do agrupamento. As superfícies customizadas agora são indexadas antes dessa combinação. Não foi usada transparência nem desativação de descarte de faces para esconder o problema.

Referências consultadas:

- [Foto e histórico da FN, fabricante](https://fnamerica.com/about-fn/).
- [Foto oficial do FAL usada como referência de silhueta](https://fnamerica.wpenginepowered.com/wp-content/uploads/2024/11/1947-1024x185.png).
- [FAL padrão, vista esquerda, atribuição à FN Herstal](https://commons.wikimedia.org/wiki/File:FN_FAL_Standard_Model_Left_Side_cropped.jpg).
- [Modelo disponível no Sketchfab, consultado durante a busca](https://sketchfab.com/3d-models/fn-fal-1fb2407403fd4681a9f047d64304e619). Não foi importado: a geometria adicionada é original do projeto.

## Saves e áudio

A migração é executada uma vez: seleções antigas da “FAL” passam à AK, os proprietários desse fuzil mantêm a propriedade da FAL nova e da AK, e a sensibilidade antiga passa para a AK. Uma seleção posterior da FAL nova permanece FAL. As aparências, proporções, moedas e navios não são alterados por essa migração.

O áudio novo preserva o WAV original mono PCM 16 bits/44,1 kHz, cerca de 0,596 s, sem loop ou normalização automática. A AK mantém o áudio anterior. Ambas usam os eventos, propagação espacial, pool de vozes e limitador já existentes. O teste de um carregador completo da FAL registrou 20 eventos sonoros, término das caudas e pico da mistura de aproximadamente 0,712, abaixo do clipping digital.

[A documentação do Godot recomenda WAV para efeitos curtos e repetidos e Ogg Vorbis para músicas e efeitos longos](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_audio_samples.html).

## Validação

Resultados em `tests/rifles185-results.json`, `tests/rifles185-network-*.json`, `tests/rifles185-audio-results.json` e `tests/rifles185-state-regression.json`.

Passaram **50 verificações locais e visuais**, **20 no teste multiplayer DTLS**, **8 de áudio com captura real da mistura** e **15 de regressão do combate**. As verificações visuais confirmam também que todos os vértices das superfícies entram nos índices finais e que abertura traseira e poste frontal projetam no centro da câmera, com erro inferior a 2 pixels.

Foram exercitados: migração e sua execução única, sensibilidade, equipes/classes, recusa de loadout indevido, carregadores independentes, tiro automático e recarga, origem do disparo, mira de ferro, FPP/TPP, modelo recebido pelo outro jogador e regressão de troca de granada, morte/respawn e Glock. O teste multiplayer usa três processos com UDP/DTLS em loopback; a verificação visual usa uma instância nativa renderizada do Godot.

Capturas: `work/rifles185-fal-fpp.png`, `work/rifles185-fal-ads.png`, `work/rifles185-fal-tpp.png`, `work/rifles185-fal-world.png` e equivalentes da AK.

## Acessórios e ópticas futuras

O sistema de acessórios ainda não foi implementado nesta versão. Uma luneta com imagem dinâmica pode usar uma `Camera3D` auxiliar e `SubViewport` compartilhando o mundo, com FOV menor e textura aplicada à lente 3D. Retículo, alinhamento, máscara e comportamento ao afastar o olho devem acompanhar a óptica. Para o multiplayer, sincronizam-se IDs de acessórios e orientação; cada cliente renderiza sua lente. A câmera auxiliar precisa ser desativada fora da mira e ter resolução/custo controlados, pois adiciona uma renderização da cena.

## Publicação

**1.8.5, build 55**, ativada no Ubuntu em 26/10/2026. O primeiro envio foi corretamente adiado por haver conexões ativas. Após autorização explícita do usuário para interromper a partida, os serviços foram parados, a proteção normal do publicador confirmou a ausência de sessões, e a versão assinada foi ativada. Guerra, Deserto e Naval foram confirmados ativos após a publicação. O publicador e suas validações não foram modificados.

Download HTTPS, manifesto e arquivos foram conferidos contra a exportação local. O launcher instalou a 1.8.5 e, na segunda verificação, confirmou que não precisava baixar novamente. O pacote protegido iniciou sem erros. Evidências: `work/rifles185-download-verification.log` e `tests/ubuntu-distribution-results.json`.
