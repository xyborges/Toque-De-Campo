# Atualização 1.9.1 — desempenho, rede e mobilidade

## Alterações

- Preferências de FOV/sensibilidade deixam de abrir, escrever e remover um arquivo de prova repetidamente. O diretório do perfil é resolvido uma vez por processo; alterações de configuração continuam salvas.
- O contato com água é reutilizado dentro do mesmo tick quando posição, terreno, relógio e clima permanecem iguais. Morte, embarque, teleporte e alterações do cenário invalidam o resultado.
- A térmica reutiliza o estado dos materiais quando não houve mudança de aparência ou temperatura. Personalização, destruição e restauração dos materiais continuam funcionando.
- Blindados vazios e estabilizados entram em repouso parcial, mantendo recargas e temporizadores. Apoio alterado, entrada, controle ou teleporte acordam a simulação.
- Guarani, BMP-2, Abrams e T-90 transpõem pequenos obstáculos mediante varreduras do casco completo. Não há redução de colisão nem aumento artificial de velocidade. Paredes, tetos sem folga e outros veículos continuam bloqueando a passagem.
- A suspensão verifica colisões e distingue o plano de uma rampa contínua do topo de um obstáculo alto.
- Poses recebidas são ordenadas por jogador/vida e por veículo. Pacotes antigos não podem fazer a posição, a mira ou o estado de combate regredir.
- Veículos parados reenviam seu estado a cada 500 ms para recuperar uma última atualização perdida. O envio de estados em movimento mantém a taxa nominal de 20 Hz.
- Temporizadores de rede preservam o restante do período e toleram o erro de soma de ponto flutuante. O intervalo nominal de 200 ms não deriva para 217 ms, e quadros lentos não geram uma rajada de mensagens de compensação.
- Diagnósticos opcionais separam RTT, chegada de snapshots, gaps do tick e custo do movimento. Desativados nas execuções normais; sem dados de conta nos relatórios.

## Compatibilidade

Cliente e servidor são publicados juntos: protocolo Guerra 23 e Infantaria 10. A conexão ENet/DTLS e as verificações de autoridade foram preservadas.

## Verificação

Consulte `BENCHMARK-1.9.1.md` para medições, limites do ensaio e resultados. Testes incluem os quatro blindados à frente e em ré, rampas, entulho real da biblioteca, paredes, outros cascos, teto baixo, apoio removido/editado, recarga durante repouso, sequência de snapshots e regressões de pose/headshot.

As cenas de cenário editadas pelo usuário foram preservadas. A melhoria de desempenho não depende de apagar objetos, diminuir a precisão dos hitboxes ou retirar colisões do mapa.
