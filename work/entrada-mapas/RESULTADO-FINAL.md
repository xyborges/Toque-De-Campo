# Auditoria final — entrada e mapas | IA 2 | Toque de Campo

**Data:** 7 de novembro de 2026. **Máquina da coleta:** DESKTOP-R0I0NQG, Godot 4.7.2 stable, Jolt, GTX 1650. **Baseline:** `ee969af`. **Branch de pesquisa:** `ia2/entrada-mapas-integral-20261107`, sem atualização da `main`, launcher, serviço systemd, servidor 192.168.101.24 ou build publicada.

## 1. Conclusão (até dez linhas)

1. **Não há otimização de entrada aprovada para ativação em produção:** o benefício no carregamento isolado não se confirmou no P99 da experiência gráfica.
2. Na Favela, **duas caches combinadas** reduziram a construção headless de **5.234,59 para 4.105,59 ms**: **−1.129,00 ms / −21,57%**, acima do ruído de 17,33%.
3. No mesmo teste de 60 segundos com 28 bots, `join_ready` caiu de **9.721,15 para 8.928,33 ms** (−792,82 ms / −8,16%), mas o ruído foi **14,09%**; **não declarar ganho global comprovado**.
4. Ainda restam **4,11 s de construção headless e 4,82 s além da construção** até `join_ready`, sem redução comprovada de quadros lentos.
5. Na Favela gráfica offline, a entrada variou de **21.847 para 20.369 ms** (−1.478 ms, ruído 22,97%) e o **P99 piorou de 163 para 225 ms** nos primeiros 30 s.
6. No Afeganistão, o conjunto de caches da Favela não trouxe ganho mensurável: headless `join_ready` **7.657→7.615 ms**, ruído 4,25%.
7. A Favela v25 (`7717aa5`) precisa de cache **próprio**: são 4.313 lotes, não os 4.188 da base `ee969af`; os recursos foram gerados e validados separadamente.
8. A auditoria de geometria/colisão/fallback e os testes de 28 bots/8 veículos passaram, mas a **entrada de um segundo cliente ENet não foi concluída** em ambiente de QA, portanto não há P99 multiplayer confiável.
9. **Recomendação:** preservar os caches apenas como candidatos *opt-in* com padrão OFF, sem merge nem ativação automática; investigar o tempo restante na montagem visual e validar a entrada autoritativa num cliente conectado.

## 2. Tabela de experimentos

`A` = original, `B` = intervenção. Números de cada linha são da **mesma máquina, revisão, papel e fixture**. As séries completas usam duas rodadas A/A e **cinco pares A/B** alternados (A,B,B,A,A,B,B,A,A,B), exceto a medição original de planejamento `64ad9dc`, que tem cinco pares sem o A/A novo. Ruído = amplitude dos controles A dividida pela média A; não é intervalo de confiança.

| Experimento | Escopo e 5 pares | Resultado A→B | Ruído A | Decisão | Flag / commit |
|---|---|---|---|---|---|
| Perfil dos componentes | 3 coletas, sem modificação | Bairros 1.204–1.213 ms; encostas 953–962; terreno 575–579; clutter/fiação 474–487 | — | Diagnóstico, sem otimização | `TDC_IA2_MAP_STAGES=1` / `1076dff` |
| Pular visual de caixa no headless | A/A2 + 5 A/B | Mundo 4.175→4.091 ms (−2,03%); 4/5 vitórias | **5,83%** | **Descartar**, fonte revertida | `TDC_IA2_FAST_HEADLESS_BOX=1` (revertida) / `3e47f69` |
| Colisores do terreno pré-compilados, Favela 4.188 | A/A2 + 5 A/B | Terreno 580,93→243,16 ms (−58,14%); mundo 4.108,40→3.767,91 (−8,29%); entrada 8.357,52→8.016,13 ms (−4,08%). 5/5 | 0,34% mundo; 0,38% entrada | **Aceitar apenas como candidato local opt-in** | `TDC_IA2_TERRAIN_FACES=1` / `9110ce8` |
| Planejamento dos lotes, Favela 4.188 | 5 A/B anteriores | Planejamento 1.090→302 ms (−72,3%); mundo 4.899→4.176 ms (−14,8%) | 3,8% mundo | Candidato opt-in anterior, não homologado no cliente | `TDC_IA2_HOUSING_CACHE=1` / `64ad9dc` |
| Planejamento da Favela v25 `7717aa5` | A/A2 + 5 A/B | 1.277,61→287,32 ms (−77,51%), digest igual | 3,74% | Candidato opt-in **somente nessa revisão** | `TDC_IA2_HOUSING_CACHE=1` / `b597d65`, `cf617aa` |
| Afeganistão: cache de lotes | Perfil; não há plano equivalente | 98 edifícios já memoizados: 0,009/0,002 ms | — | **Não implementar cache novo** | Não se aplica |
| Sistema operacional frio vs aquecido | Tentativa de purge + séries aquecidas já coletadas | Falha de permissão `0xC0000061`; **sem pares frios válidos** | — | Não concluir ganho com cache frio | Controle de ambiente / `883cefd` |
| Favela: conjunto final, autoridade local headless | A/A2 + 5 A/B, 60 s, 28 bots | Mundo 5.234,59→4.105,59 ms (−21,57%; 5/5); `join_ready` 9.721,15→8.928,33 (−8,16%; 4/5); **P99 68,27→91,48 ms, pior** | 17,33% mundo; **14,09% entrada**; P99 101% | **Rejeitar integração/ativação do conjunto** | Duas flags ligadas / `0659064` |
| Afeganistão: conjunto final | A/A2 + 5 A/B, 60 s, 28 bots | Mundo 5.443,83→5.417,36 ms (−0,49%); entrada 7.656,89→7.614,81 (−0,55%); 399–438 tiros entre bots | 4,61% mundo, 4,25% entrada | Sem ganho relevante; **descartar para esse mapa** | Duas flags / `0659064` |
| Favela gráfica offline, R0I GTX1650 | A/A2 + 5 A/B, 30 s após `join_ready` | Entrada 21.847,40→20.369,17 ms (−6,77%, 4/5); **P99 163,23→224,86 ms pior**; 11,22→9,61 FPS | 22,97% entrada; 43,27% P99 | **Não aceitar**; offline simula servidor e cliente juntos | Duas flags / commit de evidência GUI |
| Afeganistão gráfico offline, R0I GTX1650 | A/A2 + 5 A/B, 30 s após `join_ready` | Entrada 24.772,49→25.053,26 ms (pior 1,13%, 3/5); P99 147,54→153,36 ms; FPS 14,17→14,52 sob forte ruído | 12,86% entrada; 16,76% P99; 30% FPS | **Não aceitar** | Duas flags / commit de evidência GUI |
| Segundo cliente, ENet | 3 tentativas reais de QA, **zero sessões duplas válidas**, sem A/B | Primeiro cliente não concluiu `join_ready`; logo segundo não foi admitido | N/A | **Não medido**, sem inventar tick/P99 | Fixture ENet/arquivos de erro / `883cefd` |
| Regressões de Favela | Flag ON, fixture funcional | **39/39**; 28 bots, 8 veículos, 11.146 colisores, 4.188 casas, raycasts e hashes idênticos; fallback sem recurso/com assinatura inválida aprovado | N/A | Aprovar somente integridade funcional local | `0659064`; v25 `cf617aa` |

Observações: o custo de criar 8.698 `BoxShape3D` foi ~35,9 ms, ante ~455 ms para registrar colisores; compartilhar formas e pular loops visuais foram **descartados** em experimentos anteriores. O planejamento dos bairros e a montagem da encosta são escopos inclusivos: não somar subfases indiscriminadamente. A encosta tem outra IA responsável; não foi modificada nesta branch.

## 3. Cliente gráfico, primeiras travadas, GPU e shader

Os testes gráficos rodaram **na R0I com GTX 1650**, em Godot 4.7.2, 1920×1080, preset Médio, Forward+, escala 100%, FPS destravado, **28 slots de bots**, com a câmera de teste automatizada. Cada condição teve 2 A/A e 5 A/B e medições dos primeiros 30 segundos após `join_ready`. As contagens de bots são de slots (alguns podem morrer em combate: 27–28 vivos no fim da coleta). **Este cenário é offline e executa a simulação autoritativa no mesmo processo da apresentação**; não representa o custo isolado de um cliente remoto.

| Mapa / modo | Tempo até `join_ready` | FPS médio | P95 | P99 | Maior quadro | GPU P99 | Quadros acima de 100ms / 30s |
|---|---:|---:|---:|---:|---:|---:|---:|
| Favela A | 21.847 ms | 11,22 | 138,86 ms | 163,23 ms | 688,16 ms | 31,92 ms | 82,0 |
| Favela B | 20.369 ms | 9,61 | 180,10 ms | 224,86 ms | 680,98 ms | 32,41 ms | 109,6 |
| Afeganistão A | 24.772 ms | 14,17 | 115,05 ms | 147,54 ms | 936,26 ms | 41,71 ms | 45,4 |
| Afeganistão B | 25.053 ms | 14,52 | 112,68 ms | 153,36 ms | 886,20 ms | 37,90 ms | 43,8 |

Interpretação: a existência de quadros de **680 a 936ms** e P99 de **147–225ms** corrobora o relato de travadas na entrada; os caches de terreno e lotes **não resolveram** esse problema. São computadas as compilações de pipelines no começo e fim, e a telemetria `nvidia-smi` contém timestamps, temperatura e indicador de throttling para correlação com `join_unix_ms`. Porém, **as coletas não permitem atribuir cada travada a uma compilação de shader** sem vincular cada evento de compilação aos mesmos instantes dos quadros; também não há motivo para concluir que aquecimento GPU seja o responsável. Temperatura ~33–38 °C e sem perda de foco.

**O que realmente medimos como tempo de entrada é `join_ready`**, não a liberação efetiva do controle humano após confirmação do servidor. A separação cliente/servidor real da IA2 não foi obtida nesta rodada; as médias acima não são FPS de um cliente ENet de 28 bots remotos.

### Tentativas ENet e segundo cliente

Foram executados testes isolados (sem tocar o host 192.168.101.24): servidor autoritativo local e cliente gráfico usando DTLS/ENet, depois fixture de três processos preexistente, e finalmente host LAN isolado com cliente Forward+. O primeiro fluxo exige ingressos/tickets assinados. Na fixture preexistente, foi detectado um certificado QA vencido; outro certificado de teste válido eliminou o erro TLS, mas não concluiu a entrada. No host LAN a primeira conexão não atingiu `join_ready` após 135 segundos; o segundo cliente não chegou a entrar. Portanto **o tempo de entrada do segundo cliente, o pico de tick do servidor e o pico de quadro do cliente anterior são todos 'não medidos'**, não zero.

Os arquivos `work/entrada-mapas/enet/` guardam os logs de falhas e as séries temporais do servidor nas tentativas, compactadas; **chaves TLS e dados de contas não são versionados**.

## 4. Ordem recomendada para revisão e integração

1. **Pode receber PR para análise:** instrumentação `TDC_IA2_MAP_STAGES` e logs/versionamento de evidências (sem habilitar em produção). Mapear `join_ready` e a montagem visual/entrada em processos separados.
2. **Candidato experimental, sempre OFF até aprovação:** `TDC_IA2_HOUSING_CACHE` com o recurso da *mesma revisão* e fallback obrigatório; depois, `TDC_IA2_TERRAIN_FACES` apenas para servidor headless, com recurso assinado de 225 tiles. Testar a soma e os P99 antes de habilitar.
3. **Descartar:** fast path visual headless abaixo do ruído; cache de compartilhamento de `BoxShape3D` que piorou o carregamento; cache de lotes no Afeganistão sem rotina equivalente.
4. **Foco pós-auditoria:** montar o mundo antes da entrada de rede sem bloquear o cliente existente, descobrir os picos reais de shader/render/pose nos primeiros 30 s e validar um segundo participante autenticado. Preservar a autoridade do servidor e os 28 bots.

## 5. Ressalvas (cinco linhas)

1. **Cold-cache OS não foi medido:** falta privilégio para limpar a standby list; repetir séries aquecidas não equivale a frio.
2. **Não houve QA ENet completa nem segundo cliente admitido:** nenhum P99/tick de late join real foi legitimamente produzido.
3. **Cliente gráfico medido executa bots localmente:** não extrapolar seu FPS/P99 para cliente remoto; R0I e JJ7 não se alcançam pela rede.
4. **Ruído residual expressivo e P99 gráfico piorou:** os ganhos headless não autorizam aceitar o conjunto para produção.
5. **Favela headless não produziu disparos na fixture;** validar combate intenso, pacote exportado, controle humano e assinatura pós-export antes de qualquer ativação.

## 6. Arquivos, commits, regeneração, flags e evidências

**Branches e bases**
- Base main: `ee969af`. Pesquisa IA2: `ia2/entrada-mapas-integral-20261107`, sem merge em main.
- Perfil `1076dff`; fast box descartado `3e47f69`; cache terreno `9110ce8`; conjunto de 60 s `0659064`; GUI `96ac6bc`; tentativas de ENet `883cefd`.
- Base Favela v25 **independente**: `7717aa5`; branch `ia2/favela-v25-cache-20261107`, cache `b597d65`, evidência `cf617aa`.

**Produção tocada nesta branch:** `modes/war/scripts/favela_map.gd` (somente instrumentação e cache opt-in/fallback); recursos `maps/prepared/favela/housing_plan_cache.res` e `terrain_faces_cache.res`. Nenhum arquivo de renderizador do cliente, `bot_director.gd`, `step_motion.gd`, `main`, sistemas de produção ou autoridade de dano alterados.

**QA e medição:** `tests/ia2_housing_plan_cache_qa.gd`, `tests/ia2_terrain_faces_cache_qa.gd`, `tests/ia2_entry_combined_60s.gd`, `tests/ia2_entry_graphical_offline.gd`, `tests/ia2_entry_enet_graphics.gd`, `tests/ia2_afghan_entry_profile.gd`. Scripts, CSV/JSON/logs de A/A e A/B, perfis de GPU, tentativa de limpeza de cache e logs ENet em `work/entrada-mapas/`. A fixture ENet foi **inconclusiva**, não constitui teste de regressão aprovado.

**Regenerar na revisão exata do código, em uma linha** (Windows PowerShell; passar Godot 4.7.2; a rotina identifica automaticamente se está na v25 ou na main):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\work\entrada-mapas\regenerar_recursos.ps1 -GodotExe "C:\caminho\Godot_v4.7.2-stable_win64_console.exe"
```

O script gera lotes e, quando disponível para aquela revisão, também as 225 malhas. **Passo de CI/build:** executar o script ANTES do empacotamento, conferir o hash de cada `.res`, verificar sua inclusão no PCK exportado e fazer QA offline, ENet e P99 em máquina-alvo. **Este teste não exportou nem publicou builds.** Regerar ao mudar `favela_map.gd`, `favela_layout.gd`, `favela_street_space.gd` ou qualquer dependência que afete o mapa, e ao trocar a versão do Godot.

**Flags de teste, desligadas por padrão**:

```powershell
$env:TDC_IA2_MAP_STAGES="1"        # somente instrumentação
$env:TDC_IA2_NEIGHBOR_SUBSTAGES="1" # subinstrumentação dos bairros
$env:TDC_IA2_HOUSING_CACHE="1"     # lotes (recurso da mesma revisão)
$env:TDC_IA2_TERRAIN_FACES="1"     # terreno, SOMENTE servidor headless
```

Sem variáveis, os caminhos padrões permanecem originais. `TDC_IA2_FAST_HEADLESS_BOX` foi rejeitada e não está presente na implementação final.

**Integridade reproduzível:** `work/entrada-mapas/SHA256SUMS.txt` contém SHA-256 dos blobs do Git (normalizados entre LF/CRLF). Conferir com `python work/entrada-mapas/verify_git_sha256.py` depois do checkout. Os `.json.gz` guardam séries por quadro de tentativas de rede; os `.csv` de GPU têm timestamps da mesma janela observada pelo Godot. Nenhum número foi copiado de uma máquina para compará-lo como se fosse da outra.
