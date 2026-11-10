# Favela — remoção dos caminhos de terra residenciais (10/11/2026)

A pedido do responsável pelo projeto, a camada de 253 caminhos de terra que conectava portas de residências às ruas e aos becos foi **retirada integralmente**.

Escopo técnico:
- Removida a chamada `DOOR_PATHS.populate` e a coleta de posições das portas em `favela_map.gd`.
- Removido `favela_door_paths.gd`, o UID do gerador e o teste legado que pressupunha a existência dos caminhos.
- Removido o relatório de implementação original do conjunto de arquivos ativos; histórico preservado no Git.
- Nenhuma mudança no terreno, nos pisos das ruas, nas casas, nas portas, nas mini-ruas, nas escadarias existentes, nos acessos às lajes ou nas regras de bots.
- `maps/prepared/favela/manifest.json` deve ser atualizado como candidato pelo gerador oficial, pois o código do mapa mudou.
- Esta branch **não publica** ou reinicia o servidor ativo.

## Testes executados
- Godot 4.7.2, `tests/favela_remove_dirt_paths_qa.gd`: **PASS** (exit 0). Zero malhas `CaminhosDeTerraPortas`; zero métricas do gerador; 4.313 casas, 18 vias e 217 degraus de beco preservados.
- `tests/favela_operation_smoke.gd -- --favela-visuals`: **FAVELA_SMOKE PASS** (exit 0). 49 rotas, 104.789 instâncias visuais e 11.624 colisões; nenhum bloqueio de mini-ruas, cena completa carregada.
- `tools/prepare_favela_manifest.py`: **MATCH**, candidato v31, 68 fontes.
- A importação inicial no editor da worktree encerrou com código Windows `-1073741819`; os dois testes independentes Godot headless passaram. O baile emite aviso de um MP3 indisponível nessa importação parcial; ele usa batida de reserva, não está relacionado à remoção dos caminhos.

**Status:** remoção pronta em branch isolada. Não foi feito deploy nem publicação da build 98. A escadaria em Z e outras mudanças são independentes.
