# Favela — densidade estrutural e repertório urbano máximo (05/11/2026)

## Objetivo

Elevar a Favela do Modo Guerra sem transformar densidade em espalhamento de props.
A intervenção desta branch altera **a ocupação espacial**: fecha bolsões reais junto
às vias com lotes menores e irregulares, amplia a verticalidade percebida e acrescenta
microarquitetura doméstica e de infraestrutura, preservando envelopes de circulação.

Branch: `ia/favela-detail-max`  
Base: `f8a5654` (Favela v4)  
Worktree: `C:\Users\Joao Borges\Documents\campo-worktrees\favela-detail-max`

Os arquivos de pavimento/shader continuam pertencendo à sessão concorrente
`chat-favela-sobreposicoes`; esta branch não os sobrescreve.

## Repertório visual consultado

A composição foi orientada por imagens e estudos de **Rocinha, Paraisópolis,
Vidigal e Complexo do Alemão**, além do estudo morfológico Favelas 4D (MIT/ArchDaily).
Os padrões extraídos foram tratados como gramática espacial, não como cópia de um
local específico:

- fachadas quase coladas ao bordo da rua;
- crescimento de segunda camada em qualquer vazio realmente edificável;
- casas menores encaixadas entre volumes maiores;
- dois a cinco pavimentos e volumes superiores deslocados;
- lajes como espaço doméstico e como canteiro permanente de expansão;
- caixas d’água, varais, vergalhões, tijolos e sacos de obra nas coberturas;
- aparelhos de ar-condicionado, medidores, conduítes e calhas aparentes;
- toldos rasos e pequenos usos comerciais junto às fachadas;
- escadas externas, passarelas e patamares em morro;
- rede aérea densa, janelas pequenas/gradeadas e infraestrutura improvisada;
- interrupções deliberadas na massa construída para becos, acessos e garagens.

A regra central é: **cada espaço livre parece disputado por uso**, mas a faixa útil
de circulação, os objetivos e as bases continuam reservados.

## Infill estrutural

`favela_layout.gd` ganhou uma segunda etapa determinística de crescimento frontal.

Ela percorre os 18 corredores viários e tenta encaixar lotes menores em ambos os
lados, somente quando:

1. a casa permanece no mesmo corredor que originou a amostra;
2. a folga física da pista é >= 0,38 m;
3. o footprint não intersecta lote existente;
4. não invade reservas de base/objetivo;
5. não cai em borda externa proibida;
6. o cruzamento não troca a rua mais próxima;
7. o padrão deixa acessos periódicos intencionalmente vazios.

Os novos lotes variam aproximadamente entre 7 e 9,5 m de frente/profundidade,
2–4 pavimentos, com ocorrências controladas de 5 pavimentos. Paleta, perfil,
recuo e altura são derivados deterministicamente da posição.

### Densidade medida

| Métrica | Favela v4 | Detalhe máximo |
| --- | ---: | ---: |
| Lotes | 3.845 | **4.182** |
| Infill frontal novo | 0 | **337** |
| Bordas com casa a até 2 m | 53,9% | **68,3%** |
| Bordas com casa a até 5 m | 64,9% | **83,5%** |
| Bordas a mais de 15 m de casa | 6,4% | **2,5%** |
| Footprints sobrepostos | 0 | **0** |
| Menor folga medida da pista | 0,437 m | **0,437 m** |

O QA fixa guardrails: >=4.100 lotes, >=250 infills, >=80% das bordas com
edificação a até 5 m, <=3% acima de 15 m, zero overlaps e reserva >=0,38 m.

## Microarquitetura reutilizável

Novos prefabs autorais da biblioteca:

- `favela_caixa_dagua.tscn`
- `favela_ar_condicionado.tscn`
- `favela_varal.tscn`
- `favela_kit_obra.tscn`
- `favela_caixa_eletrica.tscn`
- `favela_toldo.tscn`

Todos possuem `library_id`, footprint, origem, superfície e alcance de LOD,
e estão no catálogo de `WarPrefabFactory`.

No mapa, os equivalentes repetidos são reconstruídos com primitivas compartilhadas
de `EnvironmentKit`, por setor. Isso evita manter milhares de cenas independentes
e permite que caixas d’água, roupas, medidores, ACs, tijolos, vergalhões, calhas e
toldos sejam agrupados em MultiMeshes.

A distribuição é contextual:

- laje doméstica → caixa d’água + varal;
- laje em obra → tijolo/cimento/vergalhão + caixa d’água eventual;
- sacada → roupa em parte dos casos;
- janela → AC e dreno em parte dos casos;
- porta → medidor/conduíte e toldo em parte dos casos;
- puxadinho → calha, descida pluvial e caixa d’água eventual.

Não foi adicionada colisão a microdecoração. Cobertura estrutural, escadas e
passarelas mantêm suas colisões existentes.

## Validações realizadas

- `favela_detail_max_qa.gd`: PASS.
- catálogo e instanciação dos seis novos prefabs: PASS.
- `favela_architecture_qa.gd`: 9.133 amostras, 126 escadas, 12 passarelas: PASS.
- travessia de bot por escada + passarela: 2/2 PASS.
- `favela_runtime_qa.gd -- --favela-bots`: 39/39, 28 bots, 8 veículos: PASS.
- smoke visual construiu 4.182 casas e >72 mil instâncias. Os únicos três
  checks do smoke que falharam foram identidade/manifesto, porque o manifesto
  está reservado e será regenerado apenas após a integração com o patch de ruas.

### Estado do desempenho

Antes da otimização dos microdetalhes, o primeiro benchmark desta branch em
GTX 1650 / 1920×1080 / Alto / escala 100% / 28 bots registrou 62,9 FPS médios,
P50 15,8 ms, P99 35,5 ms e 1.366 draw calls medianos.

A implementação foi então ajustada para batching por primitivas compartilhadas.
O benchmark final de 60 segundos deve ser considerado a referência antes da
integração.

## Integração futura com a correção das ruas

O infill desta branch foi criado sobre a planta viária pública de v4. A branch
concorrente substitui as malhas de pavimento por uma máscara unificada e protege
mobiliário contra o envelope das ruas.

A integração correta é seletiva:

1. concluir e commitar o patch de ruas;
2. integrar esta branch em uma worktree candidata;
3. resolver `favela_layout.gd` preservando o infill desta branch;
4. preservar o novo `favela_street_space.gd` e shader da branch de ruas;
5. regenerar o manifesto somente depois que as fontes finais estiverem definidas;
6. reexecutar QA de 238.926 raios, QA de densidade, 28 bots, rede e benchmark;
7. revisar novamente os mesmos ângulos de captura, especialmente
   `cobertura-na-pista`.

Não publicar automaticamente.
