# Atualização 1.9.0 — biblioteca e montagem do Guerra

## Entrega

- Diretriz permanente em `AGENTS.md`: todo novo objeto de cenário é criado primeiro na biblioteca, com materiais, colisão, origem/escala e propriedades apropriadas.
- Sete peças novas, totalizando 16: curva de estrada, cruzamento, T, rampa de estrada, curva de cais, rampa de cais e trincheira escavável.
- Conectores de encaixe, botão Encaixar, inserção e desfazer/refazer no painel Guerra. Encaixar preserva a escala da peça movida.
- Camada `infraestrutura_190.tscn` com 86 instâncias nas duas bases, nos dois portos e no vilarejo oeste. Oito casas antigas são substituídas por cenas da biblioteca; trechos de rua substituídos deixam de ser desenhados pelo gerador anterior.
- Seis módulos de trincheira com profundidade ajustável entre 0,8 e 2,8 m. O chão é escavado e restaurado ao editar a posição; revestimento, geometria e colisão acompanham a alteração.
- Rebaixamento do terreno sob cais e ajuste de fundações/estradas; árvores geradas respeitam essas áreas.
- Galeria ampliada e instruções em `BIBLIOTECA-GUERRA.md`.
- Oito objetos adicionais de destruição e infraestrutura, com versões simplificadas à distância: fachada atingida, laje desabada, carro carbonizado, entulho, carga portuária, defensa de cais, canaleta e cratera. Total de 24 peças no catálogo e mais 200 instâncias na camada de detalhamento.
- Arredores dos portos e núcleos urbanos com marcas de destruição, crateras físicas, detritos, materiais menos uniformes e relevo pequeno nas áreas industriais, preservando os acessos e as áreas de circulação.
- Agrupamento de cenário por setor/material, MultiMesh para repetições e detalhes de terreno restritos à proximidade da câmera. Fumaça maior usa seis nuvens de pool, com início/fim suaves e controle de transparência próxima da câmera.
- Sobreposições de fogo/fumaça muito grandes na tela são limitadas por explosão, considerando o FOV, para reduzir custo sobretudo ao usar zoom/térmica. Detalhes distantes mantêm a silhueta completa.
- Ruínas e destroços novos são colocados em áreas com apoio adequado e afastados das vias/edificações existentes. O asfalto gerado passa a amostrar também o centro da pista, evitando que uma faixa larga fique suspensa entre as duas bordas.
- Velocidade inicial: Glock 350 m/s, AK 715 m/s, FAL 800 m/s e sniper 900 m/s; alcance de 160/900/1100/2200 m, respectivamente. A resistência do ar reduz gradualmente a velocidade. Gravidade, direção do cano e varredura de colisão continuam sendo aplicadas pela mesma simulação no cliente e na autoridade.
- Guarani/BMP-2: 30 mm a 760 m/s, raio de explosão de 3,6/4 m. Abrams/T-90: 700/680 m/s e raio de 14/13,5 m. O dano de pico e as verificações de cobertura permanecem iguais.
- Impactos validados de mísseis em blindados produzem som metálico e tremor breve da câmera do operador e passageiros. O efeito não altera a orientação comandada da torre.
- Passagem de projéteis continua usando o segmento real percorrido: estalo supersônico acima de 343 m/s e passagem para velocidades menores.

## Implementação

`terrain_edits.gd` lê a camada salva e o porto leste antes de construir o terreno. As alterações usam índice espacial e subdividem somente as células afetadas em 0,5 m; o restante mantém sua densidade anterior. Renderização, consultas de altura e colisões usam as mesmas amostras e triângulos. O servidor lê as mesmas cenas sem criar os nós de apresentação.

A prévia do editor é temporária e não é incluída ao salvar o mapa. Movimentar/remover módulos reconstrói os setores afetados, incluindo a posição anterior. O terreno da partida é construído no carregamento; não há escavação dinâmica durante combate.

O protocolo do Guerra passa de 21 para 22 e o de infantaria de 8 para 9, impedindo partidas com mapas ou balística de versões diferentes. O protocolo do Naval permanece igual. `east_port.tscn` permanece com SHA-256 `69158EBE35AD7A932894EC978ED70663205EF1303BD95962E96F4777DB79B1CB`.

## Limites

Esta etapa amplia a montagem por cenas; o restante da cidade e do relevo ainda contém geração por código. O módulo antigo `trincheira_6m.tscn` continua sendo apenas revestimento. A escavação automática pertence ao novo `trincheira_escavavel_6m.tscn`.

As medições das vistas estáticas em 1080p são registradas em `tests/library190-visual-results.json`. Elas não demonstram desempenho de uma partida com 12 jogadores, veículos e explosões. Houve picos de frame time nos portos; não se afirma estabilidade de 60 FPS em todas as situações.

A comparação antes/depois, incluindo limitações e o teste de 12 conexões, está em `BENCHMARK-1.9.0.md`. O teste sem Profiler com um cliente completo e 11 agentes leves no mesmo PC registrou cerca de 47,7 FPS de média e 17,8 FPS no 1% low; ainda há gargalos sob essa carga compartilhada.

Resultados verificáveis e relatórios da validação ficam em `tests/library190-*-results.json`, `tests/devastation190-validation-results.json` e `tests/library190-network-*.json`. Referências fotográficas consultadas e características aproveitadas estão em `REFERENCIAS-CENARIO-1.9.0.md`.

Os ensaios com 12 clientes completos no mesmo PC registram também a concorrência de CPU e física entre 13 processos. O ensaio de agentes leves mantém o mapa completo na autoridade e no cliente que renderiza, enquanto os outros 11 agentes usam somente sua superfície de movimentação. Ambos executam o protocolo real; nenhum equivale a 12 computadores independentes. A captura com Profiler é mantida separada das medições sem instrumentação.

## Publicação e conferência

Publicada no Ubuntu `192.168.101.24`: versão **1.9.0, build 61**, com cliente, serviços, site e notas do atualizador no mesmo pacote assinado.

- Download real por HTTPS: arquivo idêntico ao publicado, assinatura e integridade verificadas, instalação pelo launcher e segunda execução sem baixar novamente.
- Executável Windows protegido: inicialização nativa conferida visualmente, pacote criptografado e bloqueios contra substituição externa de script/pacote testados.
- Duas contas reais no servidor central: disparo contínuo de FAL/AK, recarga de ambas as equipes/Glock, inclinação replicada, drone, morte por granada, respawn de oito segundos na base e disparo/saída do Guarani depois do respawn. **25 verificações, sem falhas.**
- No cliente visível desse ensaio: intervalo médio de 16,69 ms, p95 de 17,17 ms; RTT médio de 33,2 ms. O teste de 12 conexões no mesmo PC continua com os limites descritos no benchmark.

Relatórios: `tests/ubuntu-distribution-results.json` e `tests/ubuntu-war187-library190-{host,guest}.json`. O teste do editor concluiu as 12 verificações funcionais; ao encerrar, o driver Compatibility registrou aviso de duas texturas de prévia não liberadas (aproximadamente 0,67 MiB). Esse aviso não apareceu na execução nativa do jogo exportado.
