# Entrada no Guerra — A/B/A/B na base final 1.10.4

29/10/2026. Teste concluído em cópia isolada das fontes finais da1.10.4/build78, protocolo33. As otimizações de CPU e sequências de estados dessa versão estão presentes. A publicação1.10.5 com áudio/transportes ocorreu separadamente, sem alterar esta cópia.

Compatibility, GTX1650, renderização real1920×1080 (janela física1292×732 após estilo doWindows), mesma câmera e semente8377. Autoridade e dois clientes locais;28bots inicializados e parados para manter a carga de entrada. Sem disputa com outro benchmark. Máximo60FPS, VSyncdesligado. Mede quatro segundos desde o início da sincronização, não desempenho de combate. A elimina somente a espera de confirmação por lote nofixture; Busa a confirmação da produção. Demais caminhos de personagens/mapa permanecem iguais.

| Rodada | FPS médio | 1% low | Pior quadro | Sincronização |
|---|---:|---:|---:|---:|
| A1 | 49.89 | 4.43 | 389.50 ms | 448 ms |
| B1 | 57.93 | 18.48 | 69.70 ms | 805 ms |
| A2 | 53.96 | 6.46 | 187.25 ms | 408 ms |
| B2 | 57.97 | 19.12 | 61.62 ms | 827 ms |

A entrada gradual melhorou o1%low e o pior quadro em ambas as comparações. A sincronização levou804–827ms, contra408–448ms na referência, distribuindo o trabalho. Isso não garante ausência total de travadas: a cópia local ainda apresentou quadros de62–70ms durante a entrada. O cenário tem apenas quatro segundos medidos por rodada; o1%low cobre aproximadamente dois ou três quadros lentos e é sensível a eles. Não é um ensaio de partida prolongada, redeVPN ou lotação de humanos.

A construção do mundo antes da conexão levou21,6–24,0s e está fora da janela de quatro segundos. O primeiro ensaio dofixture fechou o cliente antes da confirmação final do relatório: o servidor e o outro cliente expiraram, embora a medição visual tivesse terminado. Essa rodada foi excluída. A bateria final exige confirmação explícita antes de sair; todos os processos concluíram sem falhas funcionais. A referência sem espera pode emitir avisos de buffercheio durante sua criação em rajada; não se assume que sejam erros da versão atual.

GPU registrada antes/depois:49–70°C e300–720MHz,CPU2688MHz informado peloWMI, temperatura deCPU indisponível. Os sensores são pontuais; não comprovam clocks constantes dentro de cada janela. Câmera, resolução de renderização, população e semente foram conferidas em todas as rodadas.

Evidências: `work/join1104-render-abab.json`, `work/join1104-render-final-run.log`, capturas e relatórios em `work/review1104-frozen/work/join1104-render-*`.
