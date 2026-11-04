# Trabalho concluído — 1.7.1/build 40

Publicada e conferida em 25/10/2026: site, instalador assinado, atualização sem download repetido e serviços Ubuntu Guerra/Deserto/Naval. Protocolos Guerra12/Naval6/Deserto2; todos precisam atualizar. Referências Three/Babylon preservadas.

Pedido cef21b0e e complementos implementados: sniper607,6m/s (-2%) e contraste diurno, rastro preso à física, arrasto contínuo compartilhado, áudio343m/s com filtros/oclusão/pools, impactos por superfície, crack separado, listener naval na ponte, fumaça gradual, ciclo840s(14min). Arrasto é linear analítico; não afirmar quadrático.

Ver ATUALIZACAO-1.7.1.md e tests/release171-final-status.json para arquivos, medições e evidências. Testes nativos e ENet passaram; build40 validada com contas reais nos três serviços. Core25 e cabine térmica passaram após o ajuste final de superfícies pesadas/abafamento. Package real inspecionado fora da árvore de fontes.

Benchmark PCK38 vs PCK40, GTX1650/1080p/12clientes locais/operador térmico:57,95→57,22FPS;1%low21,16→27,78;quadro máximo254,70→52,51ms. Não comprova60FPS estáveis. P95 piorou21,00→23,28ms; carga de projéteis variou. Todas execuções preservadas.

Não há trabalho pendente deste pedido. Apenas processosQA próprios/tela0(tela1 do usuário). ComputerUse indisponível por aprovação expirada na tarefa anterior; capturas nativas funcionam. Credenciais somente em distribution/private; SSH com host fixado. Nunca forçar publicação em salas ocupadas.
