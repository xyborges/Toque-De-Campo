# Favela V26 — estabilidade de colisões nas lajes

**Data:** 08/11/2026
**Branch:** `ia/favela-v26-lajes-colisao-20261108`
**Base:** `origin/main`, commit `109410a` (Favela V25 integrada)
**Status:** correção candidata / revisão por Pull Request; não representa uma publicação.

## Sintoma recebido

Ao chegar ao topo de diversas casas e tentar avançar pela laje, o jogador relata tremor repetido da posição e da câmera, com pequenos recuos; o fenômeno não se limita a lajes com objetos.

## Investigação

Em `modes/war/scripts/favela_map.gd` a plataforma de desembarque da escada externa e o telhado acessível eram duas caixas sólidas com **a mesma altura superior**. O colisor do desembarque penetrava aproximadamente **0,62 m** na caixa do telhado, criando pisos coplanares sobrepostos precisamente na transição onde o jogador anda.

Esse problema de topologia física pode fazer `CharacterBody3D.move_and_slide()`, ajuste de degrau e detecção de piso alternarem contatos ou reações, com consequências visuais na câmera. Trata-se de causa plausível e geral para uma parte da reclamação; não houve reprodução confiável do tremor reportado com jogador real.

## Mudança V26

- Mantida a **malha visual original** de `DesembarqueLaje` (1,42 × 0,24 × 1,0 m), sem alterar a estética das casas, escadarias, parapeitos, objetos, vegetação nem as regras de Linha de Frente.
- Retirado apenas o colisor sólido automático da plataforma visual.
- Criado colisor separado `BoxShape3D` para seu suporte, com ponta no limite do telhado e sobreposição residual de **1,5 cm** para não deixar frestas físicas.
- Mantidos o material, a camada de colisão e a altura superior, preservando o mesmo piso de caminhada.
- Nenhuma mudança na física global do jogador, câmera, bots ou sincronização; nenhum bloqueio especial de objetos de telhado.

## QA da correção

`tests/favela_roof_stability_v26_qa.gd` é um ensaio headless novo e determinístico: constrói a Favela V26 pela rota oficial de geração, verifica os colisores reais no `EnvironmentSector`, avalia amostras de cápsula física em lajes e percorre o desembarque com `GameStepMotion`.

**Resultados positivos (Godot 4.7.2):**

- **142/142 junções** de plataforma com telhado identificadas por dimensões de colisão, cobrindo todas as lajes acessíveis geradas.
- Sobreposição coplanar máxima medida **0,01502 m** (aproximadamente 1,5 cm). Falha automática se a junção superar 3,5 cm ou se faltar alguma plataforma.
- 117 percursos de acesso a lajes catalogados; amostra física com 30 coberturas e 12 transições completas de desembarque: **0 interpenetrações de cápsula, 0 movimentos bloqueados e 0 quadros de recuo**.
- Auditoria `favela_architecture_qa.gd`: **PASS**, 9.491 amostras físicas, 142 escadas e 16 passarelas.
- Auditoria espacial: PASS, 4.313 lotes, zero lotes sobrepostos e zero invasões de ruas.
- Smoke visual: **PASS**, mapa, casas, regiões e objetos preservados.
- Runtime: **39/39 PASS**, 28 bots e oito veículos.
- Regras de Linha de Frente: **63/63 PASS**.
- Multiplayer dedicado + dois clientes, 28 bots/2 jogadores: **18/18 PASS**.
- Manifesto da Favela: **versão 26, 68 fontes, MATCH**.

## Limitações e resultados negativos

O ensaio complementar de `WarPlayer` real criado temporariamente fora do repositório ficou sem entrada de movimento no contexto headless e retornou **15/15 trajetos sem avanço**, sem observar recuo. Como os controles não foram devidamente acionados, **esse ensaio é inválido como evidência de falha ou sucesso físico** e não será versionado como teste de aceitação.

Os testes automatizados mostram a eliminação da sobreposição e a integridade do cenário, **mas não comprovam que toda ocorrência de tremor relatada durante o jogo foi eliminada**. Ainda faltam um playtest humano em diferentes lajes, com perspectiva 1ª e 3ª pessoa, e uma rodada em sessão multiplayer real para detectar correções de posição/reconciliação de movimento.

O teste de FPS não foi repetido nesta tarefa: o número de elementos visuais permanece inalterado, mas a ausência de regressão de desempenho deve ser confirmada caso a V26 seja candidata a release.

## Integração

Manter `main` intacta e usar PR com revisão antes de merge. Não publicar build V26 apenas com esses testes: requer confirmação do tremor em partida e, se necessário, instrumentar `GameStepMotion` e reconciliação de `WarPlayer` em pontos específicos.
