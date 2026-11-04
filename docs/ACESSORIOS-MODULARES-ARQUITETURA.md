# Acessórios modulares — base compartilhada

Implementação local de 29/10/2026. Sem publicação. Os módulos de produção continuam sendo Prismática 4× e PSO 4×. Lanterna, carregador estendido e adaptador genérico aparecem somente nas definições de teste; não foram acrescentados como itens fictícios ao loot público.

## Fontes de dados

`scripts/attachments/definition.gd` define `GameAttachmentDefinition`, um Resource por modelo de acessório: ID/nome, categoria, interfaces físicas aceitas, tags/restrições, volume ocupado, peso, cena, MountReference/Eye/retícula, modificadores, comportamento, esquema de estado individual, sockets fornecidos e ajustes geométricos por perfil.

`socket.gd` define `GameAttachmentSocket`: categorias/interfaces, transformação completa, espaço, posição na interface, tags de ajuste, peças padrão substituídas e trilhos de comprimento/ocupação configuráveis. A validação não usa o nome do socket como categoria. `weapon_profile.gd` reúne esses sockets por plataforma.

Dados atuais em `scripts/attachments/data/`: duas definições de óptica e perfis FAL, AK, Glock, sniper e lançadores. Só existem encaixes correspondentes a peças reais do modelo: não foi criado trilho de mira na pistola ou rosca arbitrária nos lançadores. Interfaces específicas de carregadores/coronha/boca evitam compatibilidade apenas por nome da categoria. Novos encaixes poderão ser criados quando o respectivo hardware for modelado.

`GameAttachmentRegistry` centraliza os dados. `definition(id)`, `profile(weapon)`, `ids(category, production_only)` consultam; `register_definition`/`register_profile` permitem extensão por dados. Ajustes do suporte PSO na FAL e adaptador da Prismática na AK estão nas definições/perfis, sem condicionais de combinação no gerenciador.

## Estado e regras

Configuração de uma arma:

```
{
  "optic_top": {"id":"prism4x", "state":{}, "position":0.0},
  "receiver/rail": {"id":"example_module", "state":{"on":true}, "position":0.0}
}
```

`weapon_attachments` no personagem armazena configurações por arma. O estado individual não é salvo nos Resources compartilhados. O inventário e o servidor continuam responsáveis pela transação de propriedade/peso/munição; as funções abaixo só produzem planos validados.

`GameAttachmentState` oferece:

- `validate(weapon, raw)`: valida configuração completa e devolve `{ok,state,reason}`.
- `sockets(weapon, config)`: sockets físicos, inclusive os fornecidos por módulos. `socket_records` fornece dicionários para o HUD.
- `can_install`/`install`: interfaces, categoria, tags, conflitos, volume, ocupação e posição em trilhos. Troca retorna os módulos substituídos/dependentes em `removed`.
- `remove`: plano de remoção do conjunto completo, filhos antes do pai. O inventário confirma espaço para todos antes de efetivar, evitando órfãos.
- `valid_state`/`stateclean`: chaves tipadas e limitadas, números finitos e intervalos; padrões são copiados para a instância.
- `effective(base, weapon, config)`: parte sempre de uma cópia da base, soma valores fixos e aplica a soma de percentuais: `(base + fixos) × (1 + percentuais)`. Overrides declarados são aplicados por ordem estável de socket. Não modifica a arma-base e não acumula após repetir trocas.

Limites iniciais: 16 módulos por arma, profundidade quatro e estado de no máximo 256 bytes por módulo. Dependência circular, caminhos inválidos e sufixos de trilho falsificados são rejeitados. Um trilho pode aceitar múltiplas instâncias espaçadas quando isso estiver declarado; o tamanho do módulo impede sobreposição.

`GamePlayer.weapon_spec()` consulta atributos efetivos; disparo, recarga e recuo reutilizam esse caminho compartilhado. O BR adapta a base do lançador antes de calcular os modificadores. A redução de capacidade de carregador é resolvida pelo inventário, preservando os cartuchos existentes.

## Montagem e comportamento

`GameAttachmentManager` instancia apenas módulos instalados. Sockets são Marker3D no referencial do modelo-base. A montagem usa a transformação inteira:

`transformação do módulo = transformação do socket × inversa(MountReference)`

Sockets de acessórios filhos usam o referencial do módulo pai. FPP e TPP recebem a mesma configuração e componentes independentes. A cópia não reinstancia a arma-base nem cria todas as combinações escondidas.

`GameAttachmentBehaviors.register_factory(type, Callable)` registra um componente específico. Ele recebe ator, nó, definição e estado individual. `manager.command(path, verb, data)` encaminha comandos; remoção chama `dispose` e libera componentes/visuais. A extensão para uma lanterna não exige inserir condicionais no disparo ou na montagem. Autoridade e transmissão do comando continuam no servidor; o componente representa o estado autorizado.

`rebuild_visual(root, weapon, config)` monta acessórios em loot/preview sem ativar comportamentos de combate, luzes ou entrada. O pool pode conservar o gerenciador em metadado para manter seu ciclo de vida.

O ADS existente usa o registro de comportamento `optical`, Eye e retícula da definição. A câmera principal não muda de proprietário; somente uma lente local renderiza o mundo ao vivo. Ponto de montagem e Eye são distintos. MuzzlePoint e balística continuam os existentes. A função antiga `GameOpticCatalog` permanece como fachada de compatibilidade e `scope4x` continua um alias de loadout, mas os dados têm uma única fonte no registro universal.

## Validação desta base

- `attachment_framework_validation.gd`: **74 verificações** de interfaces com nomes arbitrários, espaço, trilho compartilhado, conflito, ciclo, remoção de adaptador/filhos, estado individual, 50 ciclos de atributos, transformação 3D com rotação e deslocamento no MountReference, módulo aninhado, FPP/TPP, comando e liberação de componente registrável.
- `optic_catalog_validation.gd`: **54 verificações gráficas** Compatibility/GTX 1650 das duas ópticas nas duas armas, troca, aliases antigos, câmera/lente ao vivo e isolamento de materiais.
- `scoped_muzzle_regression.gd`: **490 verificações**, maior diferença de aproximadamente 0,000000417 m entre cano físico e apresentação.
- Testes de transação do inventário e rede ficam com a integração BR, sem substituí-los por testes visuais desta base.

Não houve nova série de benchmarks nesta etapa. A infraestrutura só instancia os módulos presentes; não constitui medição de FPS com futuros acessórios. Novas categorias ainda precisam de modelo real, dados de encaixe, comportamento quando necessário e validação própria antes de entrarem no jogo.
