# Biblioteca regional do Deserto Afegão

Abrir `catalog_v2.tscn` no editor 3D para visualizar as cinco construções e nove peças de cenário. Arrastar a cena desejada para o mapa preserva o modelo, os materiais, os marcadores e as colisões.

No painel **Guerra** do editor, o botão **Afeganistão** abre `modes/battle_royale/scenes/map_additions.tscn`, reservada às alterações manuais. A lista passa a mostrar as peças afegãs; selecione uma e clique **Inserir**, mova e salve. **Objetos afegãos** abre a biblioteca de demonstração. Ao voltar a uma cena da Ucrânia, a lista original reaparece.

As construções possuem paredes grossas, janelas vazadas com recuo, portas abertas, vigas e pé-direito de aproximadamente 3 m. Casa térrea, casa com dois pavimentos, depósito, recinto murado e ruína possuem silhuetas diferentes. A escala recomendada é uniforme entre 0,85 e 1,15. O envelope `footprint` inclui escadas e anexos e é propositalmente conservador.

As raízes são `StaticBody3D`, sem script durante a partida. Os colisores são caixas simples e ficam junto à raiz. O nó `Geometry` agrupa a geometria por material, com LOD de malha gerado pelo `ImporterMesh`. O material usa a cor de vértice para permitir variação de tonalidade por instância em `MultiMesh`. Os objetos não exigem duplicação de materiais para cada exemplar.

Marcadores disponíveis nas construções:

- `GroundAnchor`: contato da fundação com o terreno.
- `FoundationTop`: altura de referência da base.
- `Entrance` e `Door`: acesso livre à construção.
- `LootInterior`: ponto de loot dentro de um recinto explorável.
- `LootRoof`: telhado acessível, exceto na ruína.
- `LootUpper`, `LootStorage` e `LootCourtyard`: locais adicionais específicos.
- `StairFoot`, `StairTurn` e `StairLanding`: percurso da escadaria externa até o terraço. A casa alta também possui os equivalentes com prefixo `UpperStair`.

O caixote agrícola possui `LootInterior` na tampa. Ele serve para justificar loot associado à agricultura sem espalhar armas no meio das plantações.

Choupos e salgueiros possuem colisão apenas no tronco. A folhagem é visual. O varal não tem colisão. As peças de encaixe, como muro e ponte, possuem marcadores `SnapA` e `SnapB`.

Muro e ponte também possuem os encaixes usados pelo botão **Encaixar** do painel. Os perfis afegãos não se conectam acidentalmente às estradas ou aos cais da Ucrânia.

`build_library_v2.gd` é uma ferramenta explícita de autoria; não roda com o mapa. Ela preserva qualquer arquivo já existente, inclusive alterações feitas pelo usuário. As cenas antigas e o catálogo anterior foram mantidos intactos.
