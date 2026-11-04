# Referência visual — trilhas e encostas áridas (Sinai / Santa Catarina)
**Data:** 2026-11-04  
**Projeto:** Toque de Campo — Afeganistão / BR / Guerra  
**Status:** referência incorporada ao planejamento. **Nenhuma alteração de geometria ou gameplay foi realizada por esta nota.**

## Origem e interpretação responsável

Captura de story enviada pelo usuário nesta conversa: paisagem montanhosa desértica, animais de carga caminhando por trilha estreita, pedras e cascalho no primeiro plano, povoado no vale, áreas verdes junto às casas, montanhas ao fundo. O texto visível do story menciona **"سانت كاترين" (Santa Catarina / Saint Catherine, Sinai, Egito)**. Não identificar como fotografia do Afeganistão. O enquadramento social, perfil e enquetes **não** fazem parte da referência e a captura não deve ser republicada ou incluída no pacote do jogo.

A paisagem de Santa Catarina é de montanhas muito rochosas e wadis; no Hindu Kush há povoados em encostas, áreas cultivadas irrigadas e diferenças regionais de casas de pedra e adobe. Adaptar a **lógica morfológica e a leitura visual**, e não transplantar a cidade, o bioma ou detalhes culturais do Sinai para a ficção afegã.

Referências externas de contexto:
- Governo do Egito: https://sis.gov.eg/en/egypt/tourism/famous-cities/saint-catherine/
- Turismo egípcio (trilhas de montanha): https://www.experienceegypt.eg/en/attraction-details/194/the-mountain-trails
- Encyclopaedia Iranica — Hindu Kush (agricultura, vilas, casas nas encostas): https://www.iranicaonline.org/articles/hindu-kush/
- Encyclopaedia Iranica — Deh (povoados, canais, pomares e solo fértil): https://www.iranicaonline.org/articles/deh/

## O que a imagem ensina (composição em três planos)

1. **Primeiro plano — aproximação perigosa e interessante:** trilha de terra estreita cortando a encosta, solo erodido, cascalho em manchas, pedras baixas irregulares, pequenas bordas e vegetação rala. O jogador precisa enxergar o vale, mas sua posição fica parcialmente mascarada pela própria ondulação, não por uma parede artificial de objetos.
2. **Plano intermediário — encostas que fazem sentido geológico:** material granular acumulado ao pé da parede, canais de enxurrada e microdegraus, espinhas de terreno e sombreamento discreto. Não preencher cada metro com rochedos grandes; manter a decisão de 28/10/2026 de retirar os blocos enormes das encostas.
3. **Plano distante — vale habitado que tem função:** povoado de baixa altura, lotes delimitados, caminhos que ligam casas a hortas/pomares, irrigação e linhas de árvores próximas da água, com montanhas áridas além das casas.

## Comparação com o projeto atual (leitura de código)

- O mapa já cobre 2 x 2 km com montanhas de cadeias longitudinais, erosão ampla, riacho, leito seco e vias graduadas (modes/battle_royale/map/afghan_landform.gd). O relevo físico do mapa usa amostragem de **5 m** (afghan_map.gd).
- Existem estradas de montanha a oeste e leste, 15 centros rurais, 83 construções originais e propriedades/irrigação preservadas; as etapas v11, v12 e v13 já adicionam coberturas, anexos e pátios, com regras BR específicas.
- As pedras grandes de encosta foram removidas intencionalmente em 28/10: docs/AFEGANISTAO-MAPA-REVISAO.md. **Não revogar** isso para copiar esta fotografia.
- As etapas v11–v13 estão em desenvolvimento, não publicadas; a navegação BR preparada está desatualizada e precisa ser regenerada e validada antes de qualquer alteração com impacto físico.

## Etapa proposta v14 — transição de montanha para vale (sem reconstrução do mapa)

### A. Trilhas em encosta, contornando o terreno existente
- Selecionar **um corredor piloto** na rota montanhosa oeste já registrada, próximo à passagem entre as regiões (-720, 440) e (-800, 275), evitando o curso d'água, campos, spawns, loot e zonas de acesso às propriedades. Depois estudar o corredor leste (825,240) -> (900,30).
- Criar trilhas secundárias de pedestres acompanhando **curvas de nível**, conectadas a pelo menos duas saídas seguras. Largura-alvo inicial **3,5–5 m** no trecho transitável para física/cápsula; evitar trilha cenográfica de 1 m que o personagem não consegue percorrer. Diferenciar claramente as vias de veículos.
- Inserir cotovelos suaves, pequenos degraus de erosão e terraços de observação que não sejam rampas impossíveis para bots. Preservar a capacidade de atirar a 1.700 m com pontos elevados, mas não expor toda a encosta.
- Na malha de altura original de 5 m, **não simular trilhas estreitas alterando amostras globais sem reprojetar colisões/LOD**. Preferir módulos locais de encaixe com suporte físico igual no cliente e autoridade; se houver corte real de altura, ele deve passar pelo pipeline oficial de relevo e navegação.

### B. Textura e cascalho, sem regressão dos rochedos
- Criar variações de material conforme declividade e umidade: rocha compacta/manchas de sedimentos em encostas, terra/cascalho na trilha, solo mais escuro e vegetação nas baixadas.
- Pequenas manchas visuais de cascalho com 3–5 variantes e distribuição coerente: depósitos no pé de taludes, curvas de trilha, canais de enxurrada. **Zero colisão e sombra individual** para pedras miúdas.
- Afloramentos grandes somente onde tiverem função específica e autorização futura; não reativar o gerador antigo de rochedos, escarpas ou montes aleatórios.

### C. Povoado visto do alto
- Na região de observação sobre o núcleo noroeste (-340,570) e na vila central (-260,70), usar recintos e vielas já existentes para criar **camadas visuais** de pátios, quintais, telhados baixos, divisas e um ou dois novos grupos de muros que **não fechem acessos**.
- Próximo aos canais e pomares, usar manchas de verde agrupadas; as encostas altas devem continuar secas e quase sem árvores.
- Evitar escala 1:1 da cidade fotografada; não criar grandes blocos urbanos sem interações e loot planejados.

### D. Visibilidade e desempenho
- Manter o horizonte e jogadores visíveis em distâncias longas. A novidade deve criar **oclusão física parcial e rotas de aproximação**, em vez de reduzir artificialmente o draw distance de jogadores.
- Estruturas que bloqueiam tiros precisam renderizar em todos os presets até a distância efetiva relevante (min. objetivo 1.700 m) e conservar colisão no servidor headless. Elementos decorativos podem ser ocultados a 60–120 m e instanciados por células/LOD.
- Máximo inicial piloto: **1–2 trechos de trilha de 150–250 m**, 2–3 pequenas áreas de erosão visual e <=150–250 manchas decorativas no corredor, como **orçamento de projeto**, não quantidade já criada. Só expandir após medir.
- Benchmark A/B na GTX 1650 com Compatibility, 1920 x 1080, 28 bots: mediana, P95/P99, picos de frame, chamadas de desenho e custo de construção. Metas continuam condicionadas à otimização paralela, sem prometer 60 FPS.

### E. Invariantes de BR e Guerra
- **Spawn:** preservar os pontos existentes e sua segurança; consultar mapa.spawn_candidates() e navegação preparada antes de aceitar novos blocos. Nunca gerar obstáculos em volta de spawn e portas de saída.
- **Loot:** preservar os 375 anchors anteriores e os 12 da v13; adicionar loot somente a novos interiores ou áreas físicas explicitamente acessíveis e validadas, não por haver uma pedra bonita na encosta.
- **Caminhos e veículos:** nenhum obstáculo novo corta estrada, propriedade, ligação de campo, rampa de montanha ou rota de moto/blindado. Trilhas novas de pé são classificadas à parte e não atraem direção de bots motorizados.
- **Navmesh:** rebake do BR pela cadeia oficial (e Guerra que reutiliza a área) antes de distribuir. Revalidar bots andando em trilhas, invadindo aldeias e retornando às vias. Não atualizar hashes manualmente.
- **Paridade:** física do cenário idêntica offline/servidor/cliente, gerar por semente determinística independente das sequências atuais. Desligamento reversível `--afghan-slope-stage4-before` para comparação.
- Nenhum elemento desta referência deve alterar spawns, loot, economia, armas ou zonas em silêncio.

## Critérios de aceitação v14
1. Dois caminhos úteis para a posição elevada, acesso e descida sem teleporte e sem cair por bordas.
2. 100% das novas coberturas físicas bloqueiam disparos e estão visíveis em distâncias em que bloqueiam projéteis.
3. Nenhum novo candidato de spawn ou ponto de loot inacessível; distribuição BR de 40 participantes testada em várias sementes.
4. Navegação oficial preparada e sem erros de fonte; bots e veículos mantêm as rotas originais; validar ambos os modos.
5. Comparação A/B satisfatória com as otimizações em curso. Sem aprovação de desempenho e navegação, manter local e **não publicar**.

## Decisão atual
Esta conversa apenas registra a referência e o desenho de v14; nenhuma trilha, pedra, modificação de textura ou arquivo de runtime foi implementado. A fotografia enviada foi analisada como referência artística, mas não incorporada ao repositório por conter sobreposição de rede social/dados pessoais.
