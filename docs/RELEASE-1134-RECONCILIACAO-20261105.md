# 1.13.4 ? Reconcilia??o Git, mapas e preflight

## Hist?rico integrado

- Base ia/favela-final-candidate (099a196); merge da antiga ia/release-favela-1134 (23d2ce4), preservando os commits exclusivos e as funcionalidades anteriores.
- Commit de integra??o cdfe368 em ia/release-favela-final-1134.
- O hist?rico publicado at? 1.13.3 estava n?o commitado na main. Foi preservado em commit isolado 872c6f5, ap?s conferir igualdade byte a byte com o hist?rico trazido ? candidata.
- As antigas sess?es de favela-guerra e favela-detail-max ficaram em suas worktrees e n?o foram encerradas ? for?a. Os patches revisados foram incorporados previamente.

## Identidade e artefatos

- Manifesto da Favela resolvido por uni?o de fontes e ferramenta oficial prepare_favela_manifest.py; 49 fontes, vers?o 6.
- Cinco outros mapas regenerados com tools/maps.py prepare e aprovados por tools/maps.py validate e map_release_preflight_readonly.py (5/5 READY).
- A navega??o BR do Afeg?o teve falso mismatch por CRLF/LF em sete fontes de conte?do l?gico igual. Foram preservados bytes originais via exce??es em .gitattributes. Prepara??o/valida??o confirmaram 115 regi?es, 85.076 pol?gonos e 640 spawns.
- Avisos conhecidos: um ponto candidato a spawn do Afeg?o rejeitado entre 162; relat?rio de dois recursos Jolt em uso ao encerrar processo. Navega??o e superf?cies passaram.

## QA em Godot 4.7.2

- Importa??o e smoke visual PASS.
- Favela 28 bots: 39/39; arquitetura: 8.747 amostras; detalhes: 4.199 lotes; natureza: 40.513 verifica??es.
- ENet: 18/18 e 26/26 em servidor+dois clientes independentes.
- Menu 21/21, vit?ria/derrota PASS, tanques fuma?a 47/47, desembarque/?ticas 29/29, motos de ambas as equipes PASS.
- Logs: pasta TEMP/favela-release-1134-qa e TEMP/favela-release-1134-maps-validation.

## Benchmark e restri??es

GTX 1650, 1080p, Alta, 28 bots, 45 s: m?dia 51,70 FPS, P50 17,30 ms, P99 44,96 ms, pior frame 95,40 ms, f?sica P99 21,72 ms e mediana 1.349 draw calls. Outros processos Godot da equipe rodavam simultaneamente. 60 FPS est?veis n?o comprovados.

Favela online p?blica n?o habilitada nesta vers?o. Porta 3016 pertence ao BR; servi?o p?blico da Favela na 3017 n?o foi implantado.

## Implanta??o

Usar o publicador protegido em main limpa, sem copiar chaves a worktrees. Conferir assinatura, vers?o monot?nica do build, hashes e pr?-flight de unidades Ubuntu antes de upload e ativa??o. N?o declarar implantado at? confirmar manifesto remoto autenticado.
