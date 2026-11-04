# Revisão de áudio sobre a 1.10.4

29/10/2026. Alterações locais sobre as fontes da **1.10.4**, com protocolo Guerra **33**. Esta revisão não publica nem substitui o build 78 descrito em `ATUALIZACAO-1.10.4.md`.

## Comportamento

- Os sons de morte passam por **Efeitos**; o ambiente compartilhado passa por **Ambiente**; os sons da tela de login passam por **Interface**. Esses sons antes usavam diretamente o bus geral e escapavam dos respectivos controles.
- Os players compartilhados do Guerra declaram suas categorias, e a moto do BR inicializa o mixer antes de selecionar **Veículos**. Ao sair do Naval, o ganho base da música permanece no padrão do mixer compartilhado, sem reaplicar o antigo `music_db` sobre a preferência atual.
- O VOIP mantém volume, ativação, seleção/teste de microfone e silenciamento individual. **Alcance** e **Voz próxima** foram removidos.
- VOIP e gritos de morte compartilham alcance de **55 m**, escala de atenuação de **4 m**, modelo de distância inversa e volume base de **−6 dB**. O volume do VOIP multiplica esse ganho; em 0% a saída é silenciosa. A origem da voz continua acompanhando a cabeça do personagem.
- A autoridade usa o alcance fixo e ignora o antigo alcance informado por clientes. O argumento do RPC foi preservado para manter sua assinatura. A margem existente de 2 m é apenas de encaminhamento de pacotes; a reprodução termina nos 55 m. Preferências antigas de distância são removidas ao carregar as opções e não mudam a audibilidade.
- As correções recentes de propriedade exclusiva do microfone, troca de dispositivo e mistura de canais foram preservadas. Sequências de bots, estados da operação e protocolo 33 permanecem nos sistemas da 1.10.4.

O perfil está centralizado em `scripts/combat_audio_catalog.gd`, usado por `scripts/main.gd` e `scripts/voice/client.gd`.

## Validação

| Bateria | Resultado | Evidência |
| --- | --- | --- |
| Controles de áudio, preferências e perfil de VOIP | 57 verificações, zero falhas | `work/audio-settings-functional.json` |
| Codec Opus e buffers com dados sintéticos | 423 verificações, zero falhas | `work/br-voice-codec-validation.json` |
| Encerramento e reentrada da voz | 13 verificações, zero falhas | `work/br-voice-lifecycle-validation.json` |
| Propriedade do microfone e mudança de dispositivo simuladas | 14 verificações, zero falhas | `work/voice-capture1103-validation.json` |
| Integração Naval e isolamento entre salas | 9 verificações, zero falhas | `work/revision-1102-naval-voice.json` |
| Servidor e quatro clientes ENet/DTLS locais | 17 verificações, zero falhas | `work/br-voice-network.json` |
| Ordenação de estados do Guerra | 12 verificações, zero falhas | `work/war-state-ordering.json` |
| Transições de rodada do Guerra | 17 verificações, zero falhas | `work/war-round-transition-regression.json` |
| Reprodução pelo driver WASAPI, sem microfone | 35.328 amostras consumidas; zero falhas de reprodução e zero reinicializações do player | `work/br-voice-audio-probe.json` |

A captura do mixer confirmou que Música, Efeitos, Armas, Ambiente, Veículos, Passos e Interface produzem aproximadamente metade da amplitude em 50% e **zero** em 0%. O controle Geral foi conferido pela API nativa de ganho e mute: a captura de um efeito no bus Master ocorre antes do ganho desse bus. As preferências foram salvas, recarregadas e alternadas entre dois perfis isolados.

A saída do player real de VOIP apresentou RMS de **0,027586** a 4 m, **0,002241** a 28 m e **zero** a 56 m. O controle de volume do painel, através do relay real, reduziu o RMS para **0,013781** em 50% e zero em 0%. Os controles de ativação também acionaram o cliente real. Essas medições usam um tom sintético para isolar ganho e atenuação; a reprodução Opus foi conferida separadamente.

O teste de reprodução teve inicialmente uma reinicialização ao começar junto com a criação da janela nativa. A sonda passou a aguardar 400 ms de estabilização, mantendo a exigência de zero reinicializações durante a reprodução. Na execução final, o maior intervalo de alimentação foi 25,195 ms e não houve skips. A política do jogo de reiniciar o buffer após um frame maior que 120 ms não foi alterada.

Nenhum destes testes abriu o microfone físico, gravou voz, avaliou inteligibilidade humana ou mediu áudio através da VM de produção. Os testes locais não comprovam a eliminação dos picos de recepção documentados na 1.10.4. O relatório funcional registra a versão e hashes das fontes principais usadas.

Para repetir a bateria principal, executar `tests/run_audio_settings_validation.ps1`. A rede usa `tests/run_br_voice_network.ps1`; a reprodução nativa usa `tests/br_voice_audio_probe.gd` sem `--probe-microphone`.
