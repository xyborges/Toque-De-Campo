# Favela — caminhos de terra ligando as portas às ruas e becos

Data: 09/11/2026

## Escopo
- Desenvolvimento em branch independente `ia/favela-door-dirt-paths-20261109`, sem misturar com a instrumentacao V27 das lajes.
- `modes/war/scripts/favela_door_paths.gd` gera automaticamente caminhos pedonais curtos de terra batida das entradas residenciais para o envelope da rua/beco mais proximo na direcao da fachada.
- Nao gera trilhas que saem para tras da porta, que ja encostem na rua ou que ultrapassem 9,5 m. Priorizacao leve de becos de menor largura.
- Cada trilha segue o relevo amostrado, tem largura aproximada 1,1 a 1,4 m e variacoes sutis de tom. Um unico ArrayMesh agrupa todas as trilhas; nao ha StaticBody, Area, scripts de instancia, sombra individual ou colisor adicional. A representacao fisica do terreno original permanece intacta.
- O gerador coleta as portas efetivamente construidas pela `WarFavelaMap._house`; novas trilhas surgem de forma deterministica no build.
- Dedicated/headless calcula as contagens mas nao cria geometria visual. Inclusao de `door_footpaths` e `door_footpaths_triangles` no build_metrics.
- Ficam inalteradas regras de ocupacao, escadas, navegacao IA e os colisores originais das residencias.

## Testes
- Godot 4.7.2, DESKTOP-JJ7U3G3: `tests/favela_door_paths_qa.gd` exit 0, sem errors.
- 4.313 casas, 3.351 entradas coletadas, 253 caminhos aceitos conservadoramente.
- Testes de geometria e prioridade: somente porta voltada para a rua acessivel; distancia correta ate borda do envelope; malha de terra gera triangulos e um unico nó MeshInstance3D; sem corpo de colisao.
- Teste da favela sem renderizacao: a mesma contagem de caminhos e nenhuma malha extra, sem erros.
- O import inicial do editor na worktree nova terminou recursos mas processo encerrou com exit -1073741819; nao tratar a importacao editor como PASS. O runner Godot headless e QA passaram. Visual in-game e benchmark FPS continuam pendentes antes de merge ou release.

## Decisao
Branch somente. Nao integrar main ou publicar sem validacao visual e verificação dos corredores em runtime gráfico. Acessos passam por filtro conservador; nem todas as portas receberam trilha por proximidade/orientacao; evita saturar os becos e atravessar casas.
