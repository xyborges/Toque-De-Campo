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
| Partida longa com humanos e 28 bots *juntos*, combate e motoristas | **NÃO EXECUTADO** | cenários separados testaram rede, bots e locomoção |

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
