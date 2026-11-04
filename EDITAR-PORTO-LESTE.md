# Editar o porto leste no Godot

O porto tem uma cena própria: **res://modes/war/scenes/east_port.tscn**. É uma cena 3D normal, usada pelo jogo tanto no Offline quanto no servidor. Você pode editar seus objetos diretamente.

1. Abra **ABRIR-EDITOR.bat** na pasta do projeto. Se o Godot já estiver aberto, confirme que o projeto é **campo-cartunesco-godot**.
2. No painel **Sistema de arquivos / FileSystem**, abra **modes → war → scenes → east_port.tscn** com dois cliques.
3. Na árvore da cena, selecione **PortoLeste** e pressione **F** com o mouse sobre a janela 3D para enquadrar o porto.
4. Expanda os grupos **PatioDeCarga**, **Armazem**, **Administracao**, **Cais** e **Entrada**. Selecione um contêiner ou grupo inteiro para mover suas partes juntas.
5. Use **W** para mover, **E** para girar, **R** para escalar e **Ctrl+D** para duplicar o objeto selecionado. A tecla **F** enquadra a seleção. Segure o botão direito e use WASD para navegar pela vista 3D.
6. Arraste modelos GLB/GLTF ou cenas da janela de arquivos para a vista 3D para adicionar objetos. Salve com **Ctrl+S**.
7. Use **F5** para testar o jogo completo, entre em **Guerra Offline** e vá ao porto leste. Capturar o ponto E permite selecionar o porto como implantação no menu M.

## Coordenadas

Na cena, o piso do cais é **Y=0**. No mapa ele é colocado em **X=1190, Y=4, Z=470**. Edite posições locais perto de zero; não some essas coordenadas manualmente.

- Y é altura.
- X é a largura do terminal.
- Z é o comprimento.
- O limite aproximado do cais é X entre -41 e 41, Z entre -115 e 115.
- Mantenha os acessos aos píeres e a faixa de circulação livres.

O cais estrutural, o mar, os píeres, o guindaste e a posição dos navios ainda são montados por **modes/war/scripts/harbors.gd**. A cena editável reúne os objetos do terminal leste. Assim é possível melhorar sua modelagem sem alterar captura, assentos ou física dos navios.

## Colisão

Os objetos existentes possuem nós como **CaixaCollision → Shape**. Ao mover um contêiner inteiro, mova seu grupo **Container01**, por exemplo: a aparência e a colisão acompanham juntas. Se mover só o nó da malha, mova a colisão correspondente também.

Para um modelo novo, selecione sua **MeshInstance3D** e, no menu **Mesh/Malha** da vista 3D, use **Create Trimesh Static Body / Criar corpo estático de malha triangular** quando o jogador precisar andar sobre sua geometria. Em caixas simples, prefira um **StaticBody3D → CollisionShape3D → BoxShape3D**, mais leve. Use camada de colisão **1**.

Não adicione outra superfície exatamente na altura do piso: foi isso que causou as faixas que piscavam. Deixe marcações um pouco acima do chão (cerca de 2–5 cm).

## Desempenho e publicação

No editor, as peças permanecem separadas para edição. Durante o jogo, a geometria rígida é agrupada por material; colisões e pontos interativos continuam independentes. Não execute **tools/build_east_port_scene.py** depois de editar: ele foi usado para criar a cena inicial e sobrescreve o arquivo.

Para seus amigos receberem as alterações, a cena precisa entrar em uma nova exportação e publicação. Salvar no editor altera apenas o projeto local.
