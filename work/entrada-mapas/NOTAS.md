# Cache Favela v25 — validação isolada

Base exata 7717aa5; branch ia2/favela-v25-cache-20261107; Godot 4.7.2. Não misturar o .res com main ee969af.
Flag TDC_IA2_HOUSING_CACHE=1 (padrão OFF). Um recurso de 2.376.131 bytes guarda exatamente 4.313 lotes.
Controle A/A 2 e 5 pares A/B: planner original 1.277,61 ms → cache 287,32 ms, ganho 990,29 ms (77,51%), ruído A 3,74%. Hash dos 4.313 lotes idêntico nos 12 processos: cf02c42b719d067724e2913677870aaadadcd89ba463c577a33cf905e520ea55.
Fallback testado com arquivo ausente e com arquivo de cache da main atual (assinatura incompatível); ambos regeneraram os 4.313 lotes originais. Recursos originais restaurados pelo SHA256.
QA funcional: 28 bots implantados, 8 veículos, 39 verificações sem falha. Zero disparos na fixture.
Decisão: ACEITAR candidato opt-in apenas para a revisão 7717aa5; NÃO substituir cache da main, não mesclar este branch indiscriminadamente.
Regerar: Godot 4.7.2 --headless --path <worktree-v25> --script res://tests/ia2_v25_housing_cache_qa.gd -- --mode=generate
