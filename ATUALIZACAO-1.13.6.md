# Atualização 1.13.6 — Recuperação de estado online

Estado inicial do candidato em 05/11/2026, ainda não publicado. Base 1.13.5/build 92. Guerra protocolo 37.

A recuperação do mundo detecta falta de poses e relógio mais cedo, retenta pedidos sem resposta, tolera jitter na quota e inclui o veículo ocupado ou drone controlado. Sequências impedem que respostas atrasadas rebobinem estado. Diagnóstico distingue pausa de quadros de falta de atualizações.

41 verificações unitárias, 82 regressões e 52 verificações de rede com cliente gráfico, servidor ENet/DTLS e 28 bots passaram. O ensaio inclui dez interrupções controladas, com três cenários a pé. Resultados, limites e evidências estão em `docs/CONGELAMENTOS-ONLINE-20261105.md`.

Esta atualização reduz pausas de sincronização e corrige o mecanismo de recuperação. A causa da redução espontânea de envios do servidor oficial permanece sem confirmação; não há promessa de eliminação de todos os congelamentos ou quedas de FPS.

Preparação dos mapas concluída. Favela v12 e Ucrânia v21 correspondem às fontes canônicas LF. O pipeline da Ucrânia passou 22 verificações; comparação de 17 propriedades dos recursos confirmou que navegação e geometria da grama são idênticas à base, mudando a identidade das fontes. Os demais quatro mapas continuam prontos.

Importação Godot e 22 verificações do menu Favela passaram. Repetição gráfica final com protocolo 37 e versão 1.13.6 passou novamente 52 verificações, incluindo todos os dez cenários e 28 bots. Evidência em `C:/Users/Joao Borges/AppData/Local/Temp/campo-recovery-network-on3o5vi9/`. A política de implantação passou 24 testes.

Integração, pacote assinado e publicação serão registrados abaixo conforme efetivamente concluídos.

## Pacote pronto para ativacao

Integrado na main pelo merge `9708dcd`. Build 93 / 1.13.6 preparada e assinada localmente, sem upload ou ativacao. Instalacao assinada passou 13/13 verificacoes e boot protegido passou, com DLL carregada e pacote inalterado. Preflight remoto somente leitura passou `PREFLIGHT build=93 publicado=92` e `PREFLIGHT_OK build=93`.

Arquivo `releases/game-93-832294fdcf04.zip`, 255609067 bytes. Logs `work/release1136-prepare.log`, `work/release1136-signed-install.log`, `work/release1136-preflight.log`. Servidor oficial permanece build92 ate ativacao. Validacao pos-publicacao ainda pendente.

## Publicação oficial

Build 93 / 1.13.6 publicada em 05/11/2026 por autorização do usuário. `VERIFIED_READY build=93` e `DEPLOYED build=93 version=1.13.6` em `work/release1136-deploy.log`. Manifesto HTTPS byte a byte idêntico ao assinado, `/opt/toque-de-campo/current` em `build-93`, seis serviços ativos incluindo `toque-war-favela`; executável e PCK Linux com SHA-256 iguais ao manifesto assinado.

Partida real na Favela oficial com cliente gráfico de protocolo 37: login e admissão passaram, 28 bots ativos, 3.376 quadros amostrados, 3.552 lotes de bots e 293 estados da operação recebidos, 24 respostas de recuperação aplicadas. Moto percorrida por 184,8 m e drone acionado, sem queda de conexão ou erro do QA. Evidência temporária `C:/Users/Joao Borges/AppData/Local/Temp/campo-1136-official-match-w50trpy4/client.json`. Esta partida confirma operação da build publicada, não prova ausência de todo congelamento espontâneo.

O commit `eb61911` de campo de baile, ruas e áudio da Favela foi inspecionado a pedido do usuário e não entrou na build 93. Ele conflita com o mapa e shader atuais e exige conciliação e novos testes. A tentativa de merge foi abortada e a main permaneceu limpa antes do deploy.
