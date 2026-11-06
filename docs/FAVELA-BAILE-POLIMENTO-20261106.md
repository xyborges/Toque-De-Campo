# Polimento do campo de futebol / baile — 06/11/2026

## Diagnostico
- O antigo controlador aguardava entre 8 e 38 segundos para tocar a primeira faixa.
- O som saía do centro geometrico da quadra, distante do paredao.
- A estrutura possuia colisao apenas na plataforma principal; gols, caixas e bases eram so meshes.
- As caixas suspensas e cobertura sem postes geravam objetos aparentemente flutuantes.
- As oito luzes sem luminarias visiveis tinham pouco impacto de longa distancia.

## Alteracoes
- Campo agora tem piso de concreto com faixa verde gasta, marcações, circulo central, areas, gols com redes e alambrados.
- Palco recebe piso, estrutura de trelica, pilares, fundacoes, cobertura, fascia, degraus, LED, letreiro, mesa de DJ, pratos, flight cases, retornos, paredao e caixas com cones.
- Os elementos fisicos possuem corpo estatico para cliente, offline e servidor; partes decorativas pequenas nao carregam colisao.
- A playlist de seis faixas fornecidas e preservada, com inicio imediato, emissores posicionados junto ao palco, alcance espacial aumentado e selecao tolerante a arquivos individuais ausentes.
- Se nenhum arquivo estiver presente na exportacao, um aviso explicito sera registrado e tocara uma batida instrumental original sintetizada em memoria. Nenhuma musica protegida foi adicionada ao Git.
- Seis luzes animadas, quatro fachos sem sombra e emissivos de baixo alcance de visibilidade para limitar custo grafico. Sem benchmark A/B grafico, portanto impacto real em FPS ainda precisa ser medido.

## Referencias de composicao
- Quadras cercadas por alambrados, refletores e casas da comunidade: fotografias de campo em favela e projeto do campo da Mineira.
- Paredao de som ao lado da pista com pequenos palcos: descricao academica em *No ritmo do funk* (UFRJ).
- Palco com truss, cobertura e refletores: exemplos de eventos e infraestrutura de baile no Rio.
- Imagens usadas apenas como referencia visual; nenhum modelo ou textura externo foi copiado.

## Validacao
- Godot 4.7.2: `--check-only` do controlador PASS; `tests/favela_baile_qa.gd` PASS em 120 verificacoes, incluindo 104 StaticBody3D e paridade cliente/servidor, audio, DJ, fachos e luzes.
- Godot 4.7.2: `tests/favela_runtime_qa.gd` PASS em 37 verificacoes, 8 veiculos sem sobreposicao. Medicao de criacao do mundo na rodada final: 4496.629 ms.
- Aviso residual de recursos/objetos ainda em uso ao sair do QA isolado. O QA terminou com exit code 0; investigar lifecycle no teste em rodada posterior.
- Nao houve audicao humana da musica nem inspeção visual com camera em jogo; testar localmente antes de integrar.
- Testar adicionalmente no cliente a 0, 30, 100 e 200 m: volume, localizacao, audibilidade de tiros, luzes a distancia e passagem pela escada.
- Confirmar que os MP3 fornecidos pelo usuario estao no pacote do cliente e com licenca de distribuicao.
- A integracao na main e publicacao permanecem pendentes de solicitacao.
