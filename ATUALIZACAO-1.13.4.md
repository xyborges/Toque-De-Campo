# Candidato 1.13.4 — Favela e melhorias de combate

**ESTADO: NÃO PUBLICADO. CANDIDATO INTERNO DE INTEGRAÇÃO.**

Data: 05/11/2026. Branch: `ia/release-favela-1134`. Worktree: `campo-worktrees/release-favela-1134`.

Este documento registra o candidato para outras IAs. Não foi gerada uma build assinada, não foi chamado `distribution/publish.py` nem `publish_ubuntu.py`, não houve upload ao servidor, mudança de serviços ou merge com a `main`. O manifesto de downloads continua na versão anterior.

## Conteúdo reunido

- **Guerra · Favela:** operação isolada de 1,5 × 1,5 km com Polícia × Bandidos, objetivos A–E, 2 Guaranis da polícia, 6 motos dirigíveis e infraestrutura urbana densa. Código base v4 proveniente de `ia/favela-guerra`.
- **Menu JOGAR:** seleção da Favela com equipe, classe e equipamentos. O botão único **JOGAR COM BOTS** inicia a operação offline. A conexão online não é anunciada como pronta.
- **Identidade do mapa:** manifesto de desenvolvimento da Favela recalculado para **versão 5**, `status: testing`, com 27 fontes e hashes verificáveis por `python tools/prepare_favela_manifest.py`. Com `--write`, a ferramenta atualiza somente esse manifesto na worktree.
- **Blindados:** correção de posições de saída e prevenção de luneta indevida na pistola, reunida de `ia/desembarque-opticas`.
- **Fumaça de tanques destruídos:** plumas visíveis a longa distância e orçamento visual limitado, de `ia/fumaca-tanque-distante`.
- **Resultados de partidas:** cerimônia de vitória, derrota, empate e resultados neutros, de `ia/resultados-vitoria-derrota`; não altera a câmera de morte de outros modos.
- **Bots de motocicletas:** direção com aceleração contínua e menos para/arranca no Afegão, de `ia/moto-bot-movimento`.
- **Granada M18:** a escolha direta entre explosiva e fumaça já vinha da `main` anterior; foi preservada.

Nenhum mapa ou arquivo atualmente não commitado pela IA de correções de ruas da Favela foi copiado para este candidato. A preparação original do Afegão v13, Battle Royale e Ucrânia foi preservada.

## Testes executados no candidato (Godot 4.7.2)

| Ensaio | Resultado |
|---|---|
| `favela_menu_release_qa.gd` | **21/21**; clique real no cartão, equipamentos, offline e quatro resoluções (800×600 a 1920×1080) |
| `favela_operation_smoke.gd` sem visuais | **PASS**, sem erros de script |
| `favela_operation_smoke.gd --favela-visuals` | **PASS**, incluindo 48.182 instâncias visuais geradas |
| `favela_runtime_qa.gd --favela-bots` | **39/39**; 28 bots implantados, 5 objetivos, 8 veículos sem interpenetração de spawn |
| `favela_architecture_qa.gd` | **9.133 amostras físicas**; 12 pontes e 126 escadas, sem falhas |
| `match_result_ui_qa.gd` | **PASS**, vitória/derrota/empate/neutro, cronômetro e animação |
| `war_tank_smoke_distance.gd` | **47/47**, sem erros de script ou vazamentos no encerramento após ajuste do teste |
| `war_vehicle_exit_optic_regression.gd` | **29/29**, incluindo Guarani, BMP-2, Abrams e T-90 |
| `war_bot_motorbike_continuity.gd` (equipes 0 e 1) | **PASS em ambas**, 600 quadros por equipe, aproximadamente 69 m de deslocamento cada, sem travas contínuas |

Esses testes demonstram funcionamento local do candidato; **não** provam partida online de 20 min, benchmark integral em vários computadores, todas as trajetórias dos bots, nem os recursos que a outra IA ainda está desenvolvendo.

## Bloqueios para qualquer publicação posterior

1. **Favela online desabilitada por segurança.** Porta **3016** já pertence ao broker do Battle Royale. A operação Favela recebeu a porta local planejada **3017**, mas não existe unidade Linux `toque-war-favela.service` aprovada pelo publicador. Não reivindicar disponibilidade online sem criar, validar e implantar serviço dedicado, permitir porta e executar DTLS com clientes reais.
2. **Outros manifestos estão desatualizados neste candidato** porque `tools/maps.py` monitora fontes comuns e a adição da Favela/modificações de bots/veículos mudou as assinaturas. O teste `work/check_maps_release.py` detectou incompatibilidades em Ucrânia, Afeganistão, Deserto, Escritório e Naval. Regenerar/validar após congelar o conjunto final de scripts e mapas; não editar hashes manualmente.
3. **Mapa Favela ainda sendo trabalhado por outra IA.** A correção de ruas/sobreposições está ativa na worktree `favela-guerra` e não foi integrada aqui. Quando for concluída, revisar diffs, refazer o manifesto da Favela e repetir os testes.
4. **FPP/TPP CollisionRig experimental não integrado:** há avaliação de performance ativa em outra worktree. Não incluir seus commits sem aprovação e benchmark.
5. **Pendente:** smoke de rede Favela após integração final, desempenho GPU durante combate prolongado, navegação completa de veículos e bots e pré-flight assinado do Linux.
6. A `main` estava com `distribution/release-history.json` alterado por outro trabalho. **Não sobrescrever, restaurar nem mesclar essa alteração sem reconciliação.**

## Handoff para a próxima IA

Trabalhar com os commits da branch `ia/release-favela-1134`. Validar todos os conflitos contra `main` quando os demais trabalhos estiverem prontos, executar o pipeline de preparação completo e a suíte de regressão. Somente após a autorização expressa do usuário avaliar publicação.

**Proibição atual de publicação:** não executar o publicador, upload, assinatura, reinício de servidores ou atualização de downloads.
