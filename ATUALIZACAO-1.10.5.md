# 1.10.5 — Áudio e transportes

29/10/2026. Publicação autorizada pelo usuário para reunir as entregas prontas dos outros chats. Base: 1.10.4/build 78; Guerra protocolo33 preservado. **1.10.5/build79 publicado e verificado na VM Ubuntu.** O publicador confirmou VERIFIED_READY build79 e DEPLOYED build79 version1.10.5; a consulta final confirmou o caminho /opt/toque-de-campo/releases/build-79 e os quatro serviços ativos.

## Entregas reunidas

- Controles de volume respeitados pelos sons de morte (Efeitos), ambiente (Ambiente), login (Interface) e retorno do Naval (Música).
- VOIP com alcance fixo55m, atenuação4m e ganho base−6dB, compartilhado com os sons de morte. Removidos os ajustes de distância; mantidos volume, dispositivo/teste, ativação e silenciamento. Origem acompanha a cabeça do personagem. Autoridade ignora distância antiga informada pelo cliente.
- Captura exclusiva entre teste e transmissão, diagnóstico por tentativa/canal, encerramento de voz na saída e reabertura limitada ao trocar/perder dispositivo preservados.
- Motos do Guerra destruídas retornam após15s; abandonadas após180s. Motos ocupadas não retornam automaticamente. Não se afirma que motos do BR reaparecem durante a partida.
- Todas as correções de entrada, terreno/câmera do BR, bots, placar e otimizações de personagens, assim como a ordenação por ator/vida e por geração/relógio da1.10.4, são preservadas.

## Validação das entregas

A bateria de áudio concluiu57verificações; os hashes das sete fontes registrados nela correspondem às fontes desta publicação antes da mudança de versão. NativeOpus423, ciclo13, captura14, integraçãoNaval9, redecom4clientes17, ordenação12 e transições17 também passaram no chat de áudio. O relatório `REVISAO-AUDIO-2026-10-29.md` contém as medidas e limites.

A validação de ópticas e transportes foi repetida antes de exportar:55verificações aprovadas. Não foram abertas novas capturas físicas de microfone. O usuário havia esclarecido que o microfone estava desativado.

## Limites e trabalho seguinte

Os picos ocasionais de recepção permanecem em investigação e não são anunciados como corrigidos nesta entrega. O A/B gráfico pedido para a base final da1.10.4 está sendo repetido em fixtures separados. Experimentos de transporte não entram nesta versão sem ganho comprovado.


## Publicação e pacote

- Instalação assinada do build79:13verificações, bootnormal doEXEprotegido eDLLdevozcarregada.
- LinuxPCK:116verificações, incluindo recursos de navegação, ausência de testes/chavesprivadas/codecservidor e valores reais de voz55m e retorno15s/180s.
- SalaBRLinuxisolada iniciou o mapa completo em9,0s e ficou pronta; o processo foi encerrado após a verificação.
- Ativação comsalasvazias,backupbefore-build-79.sqlite e política existente de rollback.
- HTTPSfixado àCAprivada:manifesto idêntico ao assinado,launchercomhashcorreto e download completo221.504.082bytes comSHA2565a5f1dac64217c95bc821e9a645be5d071dc273799f9b76e30e92a9d687d1107.
- Naval,PvP,Guerra eencaminhadorBRativos,semERRORouSCRIPTERRORnoslogsdeinicialização. Não se apresenta esta consulta como teste departida prolongada.

Evidências:work/release1105-signed-install.json,work/release1105-pack.json,work/br79-linux-preflight.json,work/release1105-deploy.log,work/publication1105-verified.json.
