# Revisão e publicação — Toque de Campo 1.8.1

Publicada no Ubuntu `192.168.101.24` em 26/10/2026, build **49**. A versão anterior em produção era 1.8.0, build 48. Download e notas: http://192.168.101.24/

## Comparação com o pedido de morte e respawn

| Pedido | Implementação e validação |
|---|---|
| Avisar que o jogador morreu | Painel `VOCÊ MORREU` com contagem regressiva, usando o tema existente. Captura visual em `work/respawn181/death-notice.png`. |
| Reaparecer após 8 segundos | Prazo definido pelo servidor; não exige abrir o menu M. Teste ENet local: 7,999 s, dentro da resolução de um passo físico de 1/60 s. Servidor central: 8,043 s observados no cliente, incluindo transmissão e processamento. |
| Preservar a seleção de implantação | Usa a seleção salva para a próxima vida; na ausência dela, restaura classe, arma, loadout e ponto anteriores. Se o objetivo foi perdido, usa a base. |
| Ficar parado enquanto morto | Velocidade zerada; movimentação do personagem e atualização de posição recebida são rejeitadas durante a morte. |
| Poder girar a câmera | Mouse testado na janela nativa enquanto morto. A câmera cinematográfica não toma o controle nesse intervalo. |
| Não disparar, trocar armas ou embarcar | Bloqueios locais e validação no servidor. Testadas também solicitações de rede indevidas de tiro, equipagem, recarga, implantação antecipada e entrada em veículo. |
| Voltar corretamente ao combate | A luneta é encerrada ao morrer. O respawn restaura TPP, corpo, classe e arma, ocultando o aviso e a apresentação FPP. Um segundo cliente confirmou a restauração do personagem. |

## Problemas adicionais encontrados e corrigidos na revisão

- O aviso usava o histórico de mortes como alternativa ao estado atual. Isso podia exibi-lo indevidamente na implantação de uma nova rodada. Agora depende do estado de respawn daquela vida.
- O tratamento de mouse adicionado anteriormente não encaminhava o movimento para a câmera de um veículo operado por um jogador vivo. O fluxo normal de entrada foi restaurado e validado na janela nativa.
- O cliente podia começar mostrando 9 segundos por diferença entre os relógios. A confirmação confiável de implantação agora inclui o relógio do servidor; a apresentação fica limitada ao intervalo de 8 segundos.
- Pacotes de dano de vidas anteriores são descartados antes de modificar o cronômetro ou a apresentação de morte.
- O protocolo do Guerra passou a 14 para exigir a atualização dos clientes junto com o servidor.

## Trabalho anterior incluído

A publicação também inclui a otimização de materiais/instâncias do cenário, a troca de material da visão térmica, as correções na implantação e navegação dos bots offline e o uso dos eventos confiáveis de equipagem para reconstruir o modelo remoto da arma. As medições anteriores estão em `RELATORIO-BENCHMARK-1.8.1.md`.

**Limite de desempenho:** os benchmarks anteriores ainda não demonstram 60 FPS estáveis em 1080p. Esta revisão não realizou uma nova medição de FPS e não atribui ganhos de desempenho ao ajuste de respawn.

## Verificações concluídas

| Verificação | Resultado |
|---|---|
| Morte/respawn e transições de rodada | 16 verificações, 0 falhas. |
| ENet real: servidor local e dois clientes, um com janela gráfica | 22 verificações, 0 falhas. Inclui mouse, aviso, câmera de veículo, bloqueios no servidor e observador remoto. |
| Otimização/material/térmica | 19 verificações, 0 falhas. |
| Política de publicação e rollback | 14 testes, 0 falhas. |
| Duas contas reais no Ubuntu, sem desvio de autenticação | 22 verificações, 0 falhas. Inclui morte por granada real, implantação salva, sincronização e persistência de uma morte sem conceder abate/moedas. |
| Exportação Windows e Linux | Concluída, sem erros de script. |
| Pacote final | Protocolo 14, respawn de 8 s e recursos existentes presentes; cena QA excluída. |
| Download e atualizador | Manifesto/arquivos conferidos, instalação real da 1.8.1 e segunda abertura sem novo download. |
| Executável publicado | Inicialização headless sem erros. |
| Serviços | Guerra, PVP Deserto, Naval, nginx e PHP ativos; diretório corrente em `/opt/toque-de-campo/releases/build-49`. |

## Publicação

- Manifesto e arquivos assinados pelo mecanismo existente.
- SHA-256 do pacote Windows: `f0de16fcc4782654513281826e4d490d6bc429e5d9f8c6fcaedd211e7c1beb67`.
- Arquivo público: `releases/game-49-f0de16fcc478.zip`.
- Publicador confirmou `VERIFIED_READY build=49` e `DEPLOYED build=49 version=1.8.1`.
- Notas da atualização publicadas no site e incorporadas ao manifesto usado pelo instalador/atualizador.

Evidências: `work/respawn181/`, `tests/war-death-respawn-results.json`, `tests/ubuntu-war-respawn-host.json`, `tests/ubuntu-war-respawn-guest.json` e `tests/ubuntu-distribution-results.json`.
