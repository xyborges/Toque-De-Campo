# Modo Guerra — Operação Favela (2026-11-04)

## Estado e segurança Git

- Branch isolada: `ia/favela-guerra`, worktree `campo-worktrees/favela-guerra`.
- Baseline da `main` no início: `e4f73fc`, sem alterações locais.
- Regras lidas e seguidas: `AGENTS.md`, `docs/COORDENACAO-IA.md`, `docs/GIT-LOCAL-E-IA.md`.
- Coordenação: sessão principal `20261104-230224-ca870303`; sessões de navegação, minimapa e QA separadas.
- Preservados os arquivos e conteúdo do Afeganistão, Ucrânia e BR.
- Sem merge na `main`, release, build distribuída ou alteração no servidor de produção.

## Escopo implementado

Operação `favela` exclusiva de **Guerra**, com mapa de 1.500 × 1.500 m, seed determinística `241106`.
Ambientação: favela brasileira fictícia com morro e mata ao norte, acesso urbano ao sul,
avenida principal curvilínea e ruas secundárias, microdetalhes, casas densas 1–5 pisos,
lajes (parte delas acessível por escadas), fachadas, obras inacabadas, portões, caixas-d'água,
varais, carros queimados, pneus, entulhos, postes e barricadas.

### Equipes

| Elemento | Equipe 1 — Polícia | Equipe 2 — Bandidos |
| --- | --- | --- |
| Base | Área urbana externa `(-470, 590)` | Na parte alta urbanizada `(280, -500)` |
| Uniforme | Preto/grafite e equipamento tático | Vermelho escuro/preto e roupas casuais |
| Lançador | Nenhum RPG/Stinger | RPG-7 na classe anti-tanque |
| Veículos | 2 Guaranis APC e 3 motos | 3 motos; nenhum blindado |

Os cinco objetivos estão distribuídos entre Entrada, Escadaria, Praça, Lajes e Reservatório.
Mantém-se o sistema já existente de captura, tickets, classes, vida, armas, projéteis,
respawn, veículos, bots, loadout e autoridade de servidor. Restrições são locais à operação.

### Arquitetura técnica

- `modes/war/scripts/favela_map.gd`: terreno determinístico triangulado em 225 blocos de 100 m; amostragem idêntica em física e representação; altitude coerente com base e objetivos.
- `EnvironmentKit`: instanciação visual em células, MultiMesh e colisão categorizada. Cores e detalhes variam segundo seed.
- `modes/war/library/favela_casa_laje.tscn`, `favela_barricada_pneus.tscn`: cenas reutilizáveis com materiais, geometria, colisões, superfície e metadados LOD; registradas no catálogo do editor via `WarPrefabFactory.ITEMS`.
- `modes/war/scripts/favela_uniform.gd`: uniformes por facção, reaproveitando esqueleto e animações sem alterar hitboxes nem rig.
- `WarBotTransit` e `WarBotDirector`: grafo viário exclusivo e grade de navegação regional de 5 m para o mapa, com caminhos de veículos restritos a vias adequadas.
- `WarVehicles`: somente os tipos permitidos; identificadores únicos `v_guarani_0` e `v_guarani_1` para dois APCs.
- `WarTacticalMap`: território e estradas próprios (sem oceanos/estradas da Ucrânia).
- `scripts/main.gd` / `scripts/ui/main_menu.gd`: seleção, transição de carregamento e inicialização da Favela, offline ou conexão à sala do mapa.
- `maps/prepared/favela/manifest.json`: identidade do mapa, versão, limites e SHA-256 calculado das fontes para protocolo de compatibilidade. Porta da operação: `3016`.

### Testes automatizados executados

Godot `4.7.2.stable.official` no Windows, executável de console instalado localmente.

1. `--headless --editor --import`: **PASS**, código compilado sem erros após ajustes na nova branch.
2. `--headless --script res://tests/favela_operation_smoke.gd`: **PASS**.
3. Mesmo teste com `-- --favela-visuals`: **PASS**.
4. `--headless --script res://tests/favela_runtime_qa.gd`: **PASS**, partida offline real, frota completa, suprimentos, implantação de soldado da polícia e verificações de spawn de veículos.
5. Mesmo teste com `-- --favela-bots`: **PASS**, 28 bots existentes e implantados; movimentação observada e nenhuma falha de implantação durante teste curto.
6. `git diff --check`: **PASS**, sem erros de whitespace.
7. Regressão afegã `qa/afghan_spawn_ai_qa.gd`: **1 falha preexistente**, reproduzida também na `main` limpa (`AFGHAN_SPAWN_AI_FAIL: One-seat vehicles require server-validated bot exit`). O teste espera moto monoposto, enquanto a implementação atual de moto tem dois lugares. A Favela não modificou o número de lugares, e não corrigimos a QA alheia nesta branch.

### Métricas aproximadas da revisão

- Terreno: **225 tiles**.
- Casas/modulos edificados: cerca de **3,3 mil**; contagem varia se modificarmos reservas de base.
- Componentes visuais gerados: cerca de **34 mil** (instanciados/agrupados, não draw calls).
- Formas de colisão do EnvironmentKit: mais de **4,4 mil** (além dos colliders de terreno e peças autorais).
- Montagem do mundo em teste headless: aproximadamente **1 s sem renderização**, **3,7 s com visuais construídos**; tempos de preparação de cena, **não FPS**, nem latência em partida real.

## Limites, próximos critérios de validação

**Este é um primeiro mapa funcional e testável, ainda NÃO uma atualização publicada.**
Antes de merge/release ainda são necessários:

- Inspeção visual interativa por jogador em alta e baixa qualidade; correção de interseções, escadas, lajes, eventuais repetições visuais.
- Medição de FPS/p99 frame-time na GTX 1650 em 1080p com 28 bots, inclusive mirantes, variação de LOD e entrada/saída da partida.
- Multiplayer efetivo com cliente/servidor, integridade do manifesto, sync de bots e de veículos, objetivos, morte/respawn, sem perda de estado.
- Rodar veículos por rotas inteiras, avaliar as manobras em becos e capacidade de chegada dos bots nos cinco objetivos; testes curtos não provam AI perfeita.
- Rever o equilíbrio entre dois APCs da polícia e RPG da equipe 2 em uma partida completa.
- Avaliar qualidade artística em comparação com o Afegão, expandindo interiores e detalhes únicos sem sacrificar desempenho.
- Revisão de integração com outras branches em aberto, mantendo `main` intacta até o pipeline de lançamento.

## Uso local

Abra a worktree exclusiva e use o menu **GUERRA · FAVELA** (requer `gameplay/war_enabled`).
Para testar offline: selecione Favela e **JOGAR COM BOTS**. Servidor online precisa suportar a
operação e a porta própria; a execução isolada não hospeda o servidor público.
