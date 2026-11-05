# Favela — repertório arquitetônico complementar (05/11/2026)

## Objetivo

Este pacote não substitui a correção estrutural das faixas cinzas nem disputa os
arquivos atualmente reservados por outras instâncias. Ele prepara oito módulos
complementares, leves e reutilizáveis, inspirados em padrões recorrentes de
favelas brasileiras, para posterior integração pelo sistema de batching da
Favela.

As referências visuais consultadas incluem vistas e becos da Rocinha,
Paraisópolis e Complexo do Alemão, além do levantamento morfológico Favelas 4D
(MIT/Senseable City Lab), do artigo "O direito à laje" e do estudo brasileiro
"Entre becos e escadarias". O repertório foi usado para extrair relações
espaciais, não para copiar uma construção específica.

## Padrões observados nas referências

- Vielas e escadarias funcionam como rede cotidiana principal de pedestres,
  frequentemente mais importante do que vias veiculares internas.
- A transição rua-casa raramente é uma faixa neutra contínua: aparecem
  canaletas, degraus, soleiras, grades, muros, tubos, bancadas, comércio e
  pequenas áreas domésticas.
- O crescimento vertical cria sobreposição de lajes, puxadinhos, caixas
  d'água, antenas, varais e instalações aparentes.
- Muros de contenção e diferenças de cota fazem parte da arquitetura do
  morro; o terreno não deve parecer uma plataforma cinza perfeitamente plana.
- Infraestrutura elétrica e hidráulica aparece na fachada, mas deve ser
  organizada o bastante para leitura visual e não virar ruído uniforme.
- Pequenos comércios usam toldos, balcões, caixotes e ocupação temporária da
  borda, preservando um corredor funcional de circulação.

## Módulos adicionados

| Módulo | Papel visual | Colisão | Uso recomendado |
| --- | --- | --- | --- |
| favela_canaleta_drenagem | quebra a faixa cinza e dá função à borda | não | paralela a ruas inclinadas, junto a contenções |
| favela_muro_contencao | resolve desníveis e cria profundidade | 1 caixa simples | bolsões de encosta e lotes acima/abaixo da rua |
| favela_corrimao_beco | marca circulação vertical | não | escadarias estreitas e passagens de pedestres |
| favela_tubulacao_externa | instala infraestrutura aparente | não | fachadas laterais e fundos de casas |
| favela_antena_parabolica | melhora silhueta de lajes | não | telhados/lajes, baixa densidade por setor |
| favela_portao_grade | adiciona transição sem recuo formal | não | entradas residenciais e garagens estreitas |
| favela_tanque_lavanderia | traz uso doméstico à laje/beco | não | áreas de serviço, pátios pequenos |
| favela_barraca_rua | cria comércio informal legível | não | bolsões seguros, nunca no envelope do Guarani |

Todos os microdetalhes, exceto o muro estrutural, são intencionalmente sem
colisão para não aumentar o custo físico nem produzir bloqueios invisíveis.
Cada parte tem distância de visibilidade definida para ser compatível com LOD.
A arquitetura de integração já em desenvolvimento consegue achatar prefabs
multi-malha em lotes/sectores do EnvironmentKit, evitando um Node por prop em
runtime.

## Gramática de distribuição recomendada

### Bordas viárias
A cada 8–18 m de borda segura, escolher no máximo um elemento principal:
canaleta, portão, muro, barraca ou pequeno acesso. Microdetalhes secundários
podem acompanhar a fachada, mas não devem ocupar a faixa livre da via.

### Encostas
Prioridade: muro de contenção -> escada/corrimão -> casa superior -> tubos e
drenagem. A sequência deve explicar visualmente como a construção se apoia no
morro. Evitar paredes enterradas pela metade sem contenção visível.

### Lajes
Antenas devem ser esparsas; combinar com caixas d'água, varais e kit de obra
que já estão sendo implementados pela outra branch. Evitar colocar todos os
tipos na mesma casa.

### Comércio
Barraca e toldo devem aparecer em bolsões de uso misto e perto das rotas de
pedestres. A avenida principal pode ter concentração maior, porém mantendo o
envelope dos dois Guaranis.

## Gate de integração

Antes de registrar esses módulos em `favela_architecture.gd` ou no catálogo:

1. esperar a sessão `chat-favela-detail-max` encerrar a reserva;
2. reconciliar os oito módulos com os prefabs já criados nessa sessão;
3. usar o mesmo sistema de cache/batching multi-malha;
4. posicionar por regras determinísticas, nunca por nós vivos espalhados;
5. rodar `favela_detail_max_qa.gd`, `favela_reference_modules_qa.gd`,
   arquitetura física, 28 bots, ruas, ENet e benchmark GTX 1650;
6. comparar screenshots nos pontos de margem cinza antes/depois.

A integração só deve ser aprovada se aumentar a leitura arquitetônica sem
aumentar o percentual de bordas invadidas e sem criar nova regressão de p99.


## Auditoria da branch detalhe-máximo em andamento

A worktree concorrente `favela-detail-max` foi testada em modo somente leitura
para verificar se o aumento de lotes realmente corrige a composição espacial.

### Densidade

Resultado de `favela_detail_max_qa.gd`:

- 4.199 lotes;
- 340 lotes de infill estrutural;
- 1.301 fachadas com folga inferior a 1,6 m;
- 83,6% das amostras viárias com casa a até 5 m;
- 2,5% das amostras com casa a mais de 15 m;
- folga mínima à rua: 0,436 m;
- 0 footprints sobrepostos;
- 6.015 amostras de borda;
- pior vazio ainda em torno de (563,4; 500), com 69,5 m, na transição periférica.

O ganho é expressivo frente ao baseline anterior de 64,7% a até 5 m e 6% acima
de 15 m. A densidade de lotes, isoladamente, portanto já deixou de ser o maior
problema do miolo da Favela.

### Inspeção visual

As capturas da avenida e da encosta ainda exibem áreas grandes e lisas de
terreno cinza entre pista e edifícios. Isso demonstra que o percentual de
fachadas próximas não mede a qualidade da seção transversal da rua.

O tratamento recomendado para esses vazios é hierárquico:

1. se o vazio corresponde a desnível: muro de contenção + drenagem + acesso;
2. se corresponde a frente residencial: degrau/soleira + grade/portão +
   tubulação/medidor;
3. se corresponde a conexão de pedestres: escada + corrimão + viela;
4. se corresponde a bolsão comercial: toldo/barraca/balcão, sem invadir o
   envelope dos blindados;
5. se é transição periférica real: solo/vegetação e construção rarefeita,
   nunca uma plataforma urbana cinza contínua.

A canaleta e o muro deste pacote foram criados especificamente para resolver os
itens 1 e 3 sem inserir dezenas de colisores pequenos.

### Custo observado do detalhe máximo

Benchmark de 30 s em GTX 1650, 1920x1080, preset Alto, escala 100%, 28 bots:

- 67,2 FPS médios;
- P50 15,0 ms;
- P99 32,2 ms;
- P99 de física 18,4 ms;
- 1.253 draw calls medianos;
- pico de 2.102 draw calls.

Mesmo com o aumento visual, a média permaneceu acima de 60 FPS nessa rodada,
mas o P99 continua fora do orçamento de 16,67 ms. O custo de submissão cresceu
em relação à versão anterior (~892 draw calls medianos), confirmando que os
novos módulos devem ser integrados via batching/EnvironmentKit e distribuição
seletiva, não como milhares de Node3D permanentes.
