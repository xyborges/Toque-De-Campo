# Favela — consolidação candidata e diagnóstico de QA (05/11/2026)

## Estado de integração e preservação de outras IAs

- **Branch de integração:** `ia/favela-final-candidate`, worktree exclusiva em
  `C:/Users/Joao Borges/Documents/campo-worktrees/favela-final-candidate`.
- Base `f8a5654` com revisões de QA, prefabs de referência e compositor
  cherry-picked. As versões de ruas e detalhe máximo foram trazidas como
  **patches exatos** das respectivas worktrees, sem reescrever ou fazer
  commits nas branches de origem. Antes de adicionar as alterações integradoras,
  seis arquivos centrais tiveram hashes SHA-256 comparados e iguais.
- As sessões `chat-favela-sobreposicoes` (worktree `favela-guerra`) e
  `chat-favela-detail-max` continuam sendo trabalhos independentes.
  Sua conclusão formal e reconciliação de commits são necessárias antes de
  um merge definitivo. **Não fazer merge na main nem publicar atualização
  automaticamente.**
- A `main` já apresentava `distribution/release-history.json` alterado
  por outro fluxo. Esse arquivo não foi tocado.

## Alterações consolidadas

1. **Geometria viária:** ruas e cruzamentos renderizados por máscara única,
   `favela_street_space.gd`, com reserva e rejeição dos footprints que
   invadiriam a faixa de tráfego. As vias não precisam sobrepor novas malhas
   quase coplanares às superfícies do terreno.
2. **Densidade:** variações de lote, preenchimento de frentes,
   sobreposição de pavimentos e microarquitetura da branch detalhe máximo.
3. **Material da encosta:** fora da máscara viária, o terreno usa a
   textura-base de solo e uma paleta de terra/saibro, em vez de uma mancha
   urbano-cinza gerada por `_ground_color()`. O asfalto/concreto continua
   no shader de máscara dedicado.
4. **Bordas funcionais:** oito módulos de referência (canaleta, contenção,
   corrimão, tubos, parabólica, portão, tanque e barraca) integrados no
   catálogo e no `EnvironmentKit`. O compositor determinístico classifica
   encosta, drenagem, fachada, uso doméstico, comércio e laje;
   `streets.claim()` rejeita módulos com footprint conflitante. Os detalhes
   pequenos não recebem colisão física; muros estruturais recebem colisão.
5. **Otimização inicial:** os módulos repetidos são agrupados em setores
   para reduzir draw calls. Seu setor está sendo submetido a A/B de
   desempenho na GTX 1650; não reduzir densidade sem evidências.

## Métricas da candidata integrada

- `favela_detail_max_qa.gd`: **4.199 lotes**, 340 adensamentos, 0 lotes
  sobrepostos; 83,6% das frentes a até 5 m, versus 64,7% no baseline.
- `favela_spatial_review.gd`: 83,7% a até 5 m, apenas 1,5% das
  amostras com lacuna acima de 15 m (antes: 6,0%), 0 intrusões da
  planta residencial na via, 0 lacunas abaixo de 0,35 m.
- `favela_edge_composition_qa.gd`: plano com ~1.260 módulos
  determinísticos, incluindo ~105 contenções planejadas, com distâncias
  de reserva de estrada verificadas e variedade de contextos.
- `favela_operation_smoke.gd` após regenerar manifesto real:
  ~1.005 módulos de borda instalados, 55 sólidos de borda e
  264 posições conflitantes descartadas; ~79.186 instâncias visuais,
  10.534 colisões setorizadas, 4.199 casas e 49 nós de rota.
- `favela_architecture_qa.gd`: 120 escadarias, 12 passarelas,
  8.747 amostras físicas sem falha.
- `favela_runtime_qa.gd -- --favela-bots`: 39/39 PASS;
  28 bots implantados, 8 veículos sem colisão de nascimento.
- Rede ENet/DTLS: `run_favela_network.py` com
  `favela_online_bot_qa.gd`, servidor + 2 clientes + 28 bots:
  18/18 verificações PASS, ambos clientes receberam 30 atores.
- Importação Godot 4.7.2: PASS. Manifesto reconstruído a partir
  dos 42 arquivos `sources`; não houve bypass da integridade.

## Evidências visuais e ressalvas

Capturas 1920x1080 do render OpenGL Compatibility, preset Alto,
armazenadas em `%TEMP%/favela-final-integrated-gpu-20261105` com
vistas da avenida, encosta, beco, comércio, praça, viela, lajes,
escada, passarela e LOD.

A textura/tonalidade do solo não-circulável deixou de parecer uma
placa de pavimento cinza. Mesmo assim, algumas **encostas largas
continuam muito lisas**, sobretudo em vista oblíqua alta e ao lado da
avenida. Corrigir apenas a cor **não equivale** a preencher a borda
com contenção e acesso. As métricas de densidade e o novo compositor
melhoraram a leitura, mas a aceitação artística ainda exige inspeção
manual do jogador e eventual ajuste focalizado nessas transições.

## Desempenho: gate ainda não aprovado

No notebook GTX 1650 / i5-11400H / 1920x1080 / Alto / 28 bots,
o primeiro perfil da candidata integrada (30 s) produziu:

- 31,0 FPS médios; p50 29,53 ms; p99 98,45 ms;
- física p99 26,81 ms;
- 1.425 draw calls medianos e pico de 2.123;
- GPU média 16,4%, pico 41%, VRAM até ~1.317 MiB.

Ao mesmo tempo estavam em execução duas **outras** instâncias Godot
headless associadas à QA de veículo/IA em worktrees distintas, criando
contaminação de CPU e tornando inadequado comparar diretamente com
resultados anteriores de ~68 FPS em outras condições.

Controle executado depois na worktree `favela-detail-max` (20 s)
também com a concorrência presente: 39,85 FPS, p50 19,24 ms, p99
88,20 ms, física p99 23,3 ms e 1.268 draw calls medianos.
Portanto, **há indicação de custo adicional da candidata** além da
interferência geral. Ajuste posterior: aumentados somente os setores de lote visual dos oito
módulos complementares de 96 m para 160 m. Novo perfil da candidata
(20 s; mesma resolução e preset, 28 bots, processos Godot alheios ainda
ativos): **50,62 FPS médios**, p50 **17,36 ms**, p99 **53,37 ms**,
física p99 **22,11 ms**, 1.341 draw calls medianos, pico 2.061.
Este segundo perfil apresenta ganho expressivo sobre o primeiro perfil da
candidata e custo relativamente controlado de draw calls, mas não constitui
A/B rigoroso porque a carga concorrente pode variar a cada execução.
O teste é de custo de movimentação/partida, não prova combate prolongado
nem taxa estável de 60 FPS em todos os trajetos.

**Gate:** nenhuma aprovação de 60 FPS estáveis, nem release da Favela,
até comparar sessões sem concorrência e p99 com 28 bots no hardware alvo.

## Comandos principais de revalidação

```powershell
$g = 'C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $g --headless --editor --import --path .
& $g --headless --path . --script res://tests/favela_detail_max_qa.gd
& $g --headless --path . --script res://tests/favela_edge_composition_qa.gd
& $g --headless --path . --script res://tests/favela_reference_modules_qa.gd
& $g --headless --path . --script res://tests/favela_architecture_qa.gd
& $g --headless --path . --script res://tests/favela_spatial_review.gd
& $g --headless --path . --script res://tests/favela_operation_smoke.gd -- --favela-visuals
& $g --headless --path . --script res://tests/favela_runtime_qa.gd -- --favela-bots
python tests/run_favela_network.py --project .
```
