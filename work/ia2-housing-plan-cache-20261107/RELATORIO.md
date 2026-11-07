# IA 2 — Cache pré-calculado do planejamento determinístico da Favela

**Data:** 7 de novembro de 2026. **Máquina:** DESKTOP-R0I0NQG. **Godot:** 4.7.2 stable (ed1daf0bf). **Base oficial:** `ee969af` da `origin/main`. **Branch:** `ia2/housing-plan-cache-20261107`. Sem alteração na main, sem build pública e sem intervenção no servidor de produção.

## Objetivo

Eliminar ~1,1 segundo de planejamento síncrono dos lotes da Favela sem reduzir casas, bots, colisões, terrenos ou autoridade da rede. O planejamento depende de `favela_map.gd`, `favela_layout.gd` e `favela_street_space.gd`, e produz um resultado determinístico nesta versão. A otimização é um recurso binário `.res` gerado pelo Godot com os mesmos tipos GDScript nativos (Vector2, Dictionary, etc.).

**Flag:** `TDC_IA2_HOUSING_CACHE=1`. **Padrão OFF**. A alteração em `WarFavelaMap.housing_plan()` tenta ler o recurso apenas sob a flag. Ela compara a assinatura SHA256 dos três arquivos-fonte contra a assinatura embutida e valida o hash do conteúdo serializado. Se estiver ausente, incompatível ou inválido, usa `LAYOUT.generate()`, a rotina original. Em builds empacotados onde os três fontes `.gd` não possam ser lidos, há fallback automático. Não remover o gerador original.

**Observação:** a assinatura serve para invalidar o cache quando o código muda, não é uma assinatura criptográfica de autenticidade contra um agente capaz de adulterar todos os arquivos. O arquivo binário tem **2.307.299 bytes**. Mudanças de motor Godot precisam de regeneração/homologação mesmo que o código-fonte não mude.

## Metodologia

10 processos Godot headless isolados, cinco pares alternados `A, B, B, A, A, B, B, A, A, B`. A: gerador original; B: mesmo jogo e código, com cache ativado. Nenhuma outra flag experimental foi ativada. Todas as medições ocorreram na mesma máquina e branch, após a importação dos recursos. Logs e JSON separados por subprocesso; `housing-5pairs.csv`, `analysis.json` e reprodutor `run-five-pairs.ps1`.

| Métrica | A original | B cache | Diferença |
|---|---:|---:|---:|
| Planejamento dos lotes | **1.090,019 ms** | **302,119 ms** | **−787,900 ms (−72,28%)** |
| Construção do mundo | **4.899,041 ms** | **4.176,316 ms** | **−722,725 ms (−14,75%)** |
| Tempo até `join_ready` | **9.221,967 ms** | **8.480,008 ms** | **−741,959 ms (−8,05%)** |
| Ruído A da etapa de lotes (amplitude/média) | **4,37%** | — | O ganho local está acima do ruído |
| Ruído A da construção do mundo | **3,78%** | — | O ganho de construção está acima do ruído |
| Ruído A até `join_ready` | **7,20%** | — | Melhora global um pouco acima do ruído |
| Pares melhores na etapa / mundo / entrada | — | **5/5, 5/5, 4/5** | Uma entrada mais lenta em B |

A quinta comparação teve ~51 ms de regressão em `join_ready`, embora o planejamento tenha melhorado ~696 ms. Não interpretar o ganho localizado como garantia de tempo total em todo hardware. São testes de carregamento offline, não de FPS/P99 em 1080p nem de ENet com segundo cliente entrando.

## Integridade física e funcional

Todas as dez coletas mantiveram:
- **4.188 lotes e casas**, **225 tiles de terreno**, **11.146 formas de colisão contabilizadas pelo mapa**;
- Hash SHA256 do planejamento `9264a7d132a78bf2b9fc4966dab849dd92e66bb622321f547133febc60d3a479`;
- Hash de toda a geometria física canônica `ed382d5d98cbb2bb1471ac926b1cf890ee755213163ac8f2ddee32c33a48ca80`;
- Hash das oito consultas físicas de raycast `574841c454eb1f4ffe3703bfa0d5796c51cdb6676e428177b2468651a159f7b5`.

O recurso contém assinatura de origem `c32fd8a5d8a5b58b84f9d550ae3f1949d3316cbeecadfef721275d40eae15dd4`. O recurso é derivado do commit-base com a alteração flag-only já aplicada; `generate.log` contém o digest e o resultado do salvamento. O Godot conseguiu salvar, carregar e revalidar todas as 4.188 entradas com os tipos originais.

**Fallbacks testados com a flag ON:**
1. Recurso ausente temporariamente: `layout_status=generated`, colisão e hash intactos; asset restaurado com SHA256 idêntico.
2. Recurso presente, assinatura deliberadamente corrompida: `layout_status=generated`, geometria e raycast idênticos; asset restaurado intacto.

Arquivos: `fallback-cache-missing.log`, `fallback-signature-invalid.log`, `verify-fallback.ps1`, `verify-signature.ps1`. A restauração foi verificada por SHA256 no fim de cada experimento.

**QA offline com 28 bots:** `tests/favela_runtime_qa.gd --favela-bots` passou em Godot 4.7.2 com a flag ON: **39 verificações, zero falhas, 28 bots ativos e implantados, oito veículos sem sobreposição física**. O fixture relatou movimento de bots, mas zero disparos; portanto **não substitui combate intenso nem teste multiplayer real**.

## Critério de integração e pendências

**Aceitar como candidato opt-in de alto potencial, NÃO ativar como padrão.** O ganho de construção foi consistente acima do ruído, com geometria idêntica. Porém faltam: teste de entrada com cache frio/quente em cliente JJ7 GTX 1650, FPS/P95/P99 e travadas acima de 100 ms, segundo cliente entrando durante partida, conexão cliente-servidor dedicada, temporização de ticks do servidor, validação de colisões e tiros em partida real, e prova de que o recurso `.res` está incluído no pacote exportado e revalidado para o Godot exato do build. A assinatura precisa ser regenerada quando qualquer dependência mudar; fallback deve permanecer. Não afirmar ganho de 0,74 s em clientes até medi-lo.

**Arquivos de produção:** somente `modes/war/scripts/favela_map.gd` (loader opt-in/fallback) e `maps/prepared/favela/housing_plan_cache.res` (2,3 MB). **Testes:** `tests/ia2_housing_plan_cache_qa.gd` e UID se gerado. **Dados:** este diretório com 10 JSONs, 10 logs, dois pilotos, generator, fallback, 28 bots, CSV, análise e hashes SHA256.

**Integridade dos arquivos brutos:** `SHA256SUMS.txt` contém SHA-256 dos **blobs Git versionados**, não dos bytes de checkout do Windows. Isso evita falsos erros por conversão automática CRLF/LF. Para verificar, execute `python work/ia2-housing-plan-cache-20261107/verify-git-sha256.py` após o checkout; o script compara com `git show HEAD:<arquivo>`. A geração é feita a partir dos blobs do índice Git, com `--generate` após o stage. Arquivos `.translation` e `.csv.import` produzidos automaticamente pelo editor Godot foram excluídos, pois não são evidências de benchmark.

Este trabalho não modifica `bot_director.gd`, `step_motion.gd`, poses, hitboxes, rede, número de bots, geometria de mapa, Jolt ou o servidor dedicado. Branch isolada para revisão antes de eventual integração à main.
