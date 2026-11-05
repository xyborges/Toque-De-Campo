# Favela — fecho de QA e critérios pendentes (05/11/2026)

## Estado

A revisão independente foi feita na worktree `campo-worktrees/favela-street-review`,
branch `ia/favela-street-review`. Os testes de layout/física/rede e GPU
exercitaram o código da worktree `campo-worktrees/favela-guerra` com o patch
de ocupação viária em andamento. **Nenhum código do mapa reservado pela outra
IA foi editado nesta revisão, e nenhum merge ou publicação foi feito.**

O patch do mapa estava ainda **não commitado** e reservado por
`chat-favela-sobreposicoes` (sessão `20261105-090504-3a9ef229`).
O MAIN tinha alteração não relacionada em `distribution/release-history.json`,
mantida intocada. Não validar release a partir desse estado.

## Resultado técnico

| Teste | Resultado | Evidência |
| --- | --- | --- |
| Smoke visual Godot 4.7.2 | PASS | 3.845 casas, 9.936 colisores de setores, 48.090 instâncias, 105 fachadas |
| Manifesto/loadout/rotas da Favela | PASS | `favela_operation_smoke.gd -- --favela-visuals` |
| 238.926 raios sobre as vias | PASS | 0 objetos bloqueando a faixa física, antes eram 91 |
| Análise de 44 cruzamentos | PASS | 0 faces de rua coplanares, antes 44 |
| Layout/escadas/passarelas | PASS | 9.133 amostras, 126 escadas, 12 pontes |
| Travessia real de IA | PASS | escada e ponte 2/2, < 0,58 m do destino |
| Partida offline com 28 bots | PASS | 28 implantados, 39/39 checagens, 8 veículos sem sobreposição no spawn |
| Auditoria de lotes e bordas | PASS | 3.845 lotes, 5.816 amostras, 0 casas invadindo vias |
| Multiplayer ENet/DTLS | PASS | servidor + 2 clientes, 26/26 checagens |
| Aparência/ocupação visual das margens cinzas | **PENDENTE** | 6 capturas antes/depois, faixas cinzas extensas ainda visíveis |
| 60 FPS em Alta, 1080p, 28 bots | **NÃO ATINGIDO** | média 57,0 FPS, p99 61,8 ms |
| Servidor + 2 clientes + 28 bots (30 atores) | PASS | 18/18 em 3 processos; 12 s de movimento replicado |
| Soak de 10–20 min com humanos, bots, combate e motoristas | **NÃO EXECUTADO** | cenário prolongado e combate misto ainda pendentes |

### Objetos colocados em segurança

O novo gerador registrou 168 objetos reposicionados e 143 posições descartadas.
A varredura física confirmou ausência de formas invasivas nas vias testadas.
A inspeção por captura confirma que um conjunto de cobertura/entulho foi movido
para fora da faixa de rolamento, em vez de apenas ficar invisível.

Atenção: os raycasts amostram a malha viária da auditoria, não todas as
combinações dinâmicas de animações e envelopes de Guarani em combate.

### Rede

Rodada com três processos Godot reais (um dedicado, dois clientes) e certificado
DTLS de QA já existente em `work/security182/` do projeto principal.
O novo `tests/favela_network_qa.gd` verificou:
- negociação do conteúdo Favela e a sua autoridade;
- implantação Polícia sem RPG / Bandidos com RPG e G3;
- cinco objetivos e oito veículos (dois Guaranis policiais);
- captura real do ponto A e sincronização para ambos os clientes;
- rejeição da tentativa adversária de embarcar num Guarani;
- entrada, saída e altura física do policial ao desembarcar.

Rodada concluída com **12 verificações no servidor, 7 no cliente alpha e 7
no cliente bravo; zero falhas**. Nenhum script de teste cria contas reais ou
publica servidor. Os relatórios vão para pasta temporária de QA.

**Carga online adicional:** `tests/favela_online_bot_qa.gd` implantou 28 bots
do servidor e conectou dois humanos simultâneos (30 atores). Os dois clientes
receberam 28 bots e suas movimentações; o servidor confirmou atividade de
múltiplos bots durante uma janela de 12 s, além das oito viaturas.
Resultado **8/8 servidor, 5/5 alpha e 5/5 bravo; zero falhas**.
Esse teste confirma admissão e sincronização sob carga, **não** simula 10–20 min
de combate com entrada e saída de blindados.

```powershell
cd 'C:\Users\Joao Borges\Documents\campo-worktrees\favela-street-review'
python tests/run_favela_network.py --project 'C:\Users\Joao Borges\Documents\campo-worktrees\favela-guerra' --script 'C:\Users\Joao Borges\Documents\campo-worktrees\favela-street-review\tests\favela_online_bot_qa.gd'
```

Comando de reprodução:
```powershell
cd 'C:\Users\Joao Borges\Documents\campo-worktrees\favela-street-review'
python tests/run_favela_network.py --project 'C:\Users\Joao Borges\Documents\campo-worktrees\favela-guerra'
```

### FPS: GTX 1650, 1920 × 1080, 28 bots

| Configuração | Média | P50 | P99 | Pior quadro | Escala |
| --- | ---: | ---: | ---: | ---: | ---: |
| Antes do patch, Alta, 60 s | 55,4 FPS | 16,1 ms | 53,3 ms | 88,9 ms | 100% |
| Patch, Alta, 60 s | **57,0 FPS** | 15,9 ms | 61,8 ms | 114,3 ms | 100% |
| Patch, Baixa, 45 s | **78,8 FPS** | 13,1 ms | 33,3 ms | 116,7 ms | 75% |

Medições realizadas na placa NVIDIA GTX 1650, renderizador
`gl_compatibility`. A correção não derrubou o FPS médio em Alta no comparativo
executado, mas a variância de frame-time e a média abaixo de 60 FPS em Alta
impedem aprovação do objetivo de estabilidade. Em Baixa, a média passa de
60 FPS, mas com resolução interna reduzida.

As amostras incluem 28 bots simulados e rota de câmera de 60/45 segundos.
Não são benchmark de partida completa com dois clientes, tráfego real dos
Guaranis e explosões simultâneas.

### Evidência visual — lacuna ainda aberta

Foram reproduzidas seis vistas com as **mesmas câmeras e ângulos**:
avenida-travessa, avenida-viela, cruzamento-comercial, cobertura-na-pista,
pátio-base e vielas. As sobreposições de peças foram reduzidas, mas a extensa
cor cinza das laterais permanece em trechos, em especial **cobertura-na-pista**,
onde grandes encostas próximas à estrada estão sem composição urbana
convincente. A mudança viária resolveu interferência física e z-fighting,
**não resolveu integralmente o critério artístico de ocupação extrema**.

Causa potencial do cinza residual: `_ground_color()` dá tonalidade cinza
a praticamente toda a mancha urbana; o novo shader usa o `COLOR` dessa
malha no solo fora da máscara de pavimento. Exige inspeção de material e,
principalmente, preenchimento arquitetônico contextual (muros de contenção,
puxadinhos, escadas, canaletas e edificações onde houver envelope disponível).
Não basta trocar cinza por marrom e declarar a densidade corrigida.

Capturas e logs comparativos estão em
`C:\Users\Joao Borges\Documents\Favela-QA-20261105`.

## Gate de integração e próximos passos

**Status: pronto para integrar os testes, mas não pronto para aprovar a
estética final ou lançar o mapa.**

1. A outra IA deve concluir, testar e commitar a correção viária na branch
   `ia/favela-guerra`, encerrando a reserva; regenerar manifesto v5 com as
   fontes reais, sem ignorar a verificação de hash.
2. O integrador pode selecionar os commits da branch `ia/favela-street-review`
   (somente scripts e documentos de QA) para a branch de candidato ao
   lançamento. Rever diffs; não copiar snapshots inteiros.
3. Reexecutar os testes físico, espacial, visual, de frota e ENet após a
   integração; verificar se o shader e a geometria saíram idênticos da branch
   de origem. Inspecionar visualmente a área `cobertura-na-pista`.
4. Reduzir grandes margens cinzas com composição espacial, sem bloquear a
   avenida e as rotas de motos e Guaranis. Repetir screenshots do mesmo ângulo.
5. Obter benchmark estável de 60 FPS com 28 bots no preset-alvo; testar
   também cliente + bots + blindados durante 10–20 minutos com combate.
6. Somente após encerrar os bloqueios fazer merge revisado na `main`.
   **Não publicar a atualização automaticamente.**


## Verificação final solicitada — 11:22

### 1. A correção viária resolve o defeito físico, mas não encerra a composição visual

O estado atual não commitado de `ia/favela-guerra` substitui as malhas de rua
sobrepostas por uma máscara única de pavimento (`favela_street_space.gd`) e
reposiciona/descarta mobiliário que tocaria a faixa de circulação.

A auditoria física repetida no estado atual continua em **0 obstáculos em
238.926 amostras** e **0 superfícies quase coplanares nos 44 cruzamentos**.
Portanto, a sobreposição que motivou a captura original está tecnicamente
corrigida no protótipo atual.

Entretanto, o cinza lateral ainda tem uma causa estrutural no material:

- `_ground_color()` calcula `urban` numa mancha extensa e mistura `soil`
  com `paving` cinza;
- o novo `TERRAIN_SHADER`, fora da máscara viária, usa
  `texture(concrete_tex, UV).rgb * COLOR.rgb`;
- portanto o terreno urbano que **não é rua** continua recebendo aparência
  cinza/concretada em amplas áreas.

As capturas equivalentes confirmam a diferença: os objetos e pavimentos
sobrepostos foram limpos, mas trechos como **cobertura-na-pista** e parte dos
cruzamentos continuam com margens largas, planas e pouco ocupadas. Isso falha
o requisito artístico de densidade extrema mesmo quando a física da via passa.

**Conclusão visual:** não aprovar a Favela como final apenas com o patch atual.
É necessário separar visualmente solo/encosta/pátio das ruas e, onde houver
espaço seguro, compor essas bordas com arquitetura, contenção, escadas,
drenagem e acessos. A correção não deve ser uma simples troca de cor.

### 2. Perfil de desempenho: não é gargalo primário da GTX 1650

Foi executado um novo perfil em **1920×1080, preset Alto, escala 100%,
28 bots**, com amostragem de `nvidia-smi` durante o percurso:

- **66,6 FPS médios** em 30 s;
- P50 **15,0 ms**;
- P99 de quadro **34,5 ms**;
- P99 de física **21,3 ms**;
- **892 draw calls medianos**, pico 1.825;
- uso médio da GTX 1650: **19,6%**;
- pico de GPU: **54%**;
- VRAM máxima observada: **1.216 MiB**.

Com os ensaios anteriores, o mesmo mapa em Alta variou entre aproximadamente
**57 e 66,6 FPS médios**. A média isolada pode cruzar 60 FPS, mas os P99
continuam acima do orçamento de 16,67 ms.

Como a GPU fica muito abaixo de saturação enquanto a física excede o frame
budget em picos e o cenário mantém centenas de draw calls, o gargalo principal
é **CPU/simulação/submissão de render**, não fill-rate da GTX 1650.
Reduzir somente resolução ou textura não ataca a causa principal.

**Gate de desempenho:** ainda não considerar 60 FPS estáveis aprovados.
Priorizar redução de custo de simulação dos 28 bots, picos físicos e batching/
culling das ~900 chamadas medianas antes de sacrificar a densidade visual.

### 3. Estado de integração

No momento desta verificação, a sessão `chat-favela-sobreposicoes`
(`20261105-090504-3a9ef229`) continua **ATIVA** e mantém reserva sobre
`favela_map.gd`, `favela_street_art.gd`, `favela_street_space.gd`,
manifesto e QA de ruas. As mudanças permanecem não commitadas em
`ia/favela-guerra`.

Esta revisão não tomou posse desses arquivos nem alterou a branch principal.
A `main` continua com uma modificação alheia em
`distribution/release-history.json`, preservada sem intervenção.
