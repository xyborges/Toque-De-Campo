# Atualização 1.13.5 — Favela online, lançadores e combate

**Estado:** CANDIDATA PARA PUBLICAÇÃO — aguardando build assinada e verificação live.

Data: 05/11/2026. Branch de integração: `ia/release-1135`.

## Conteúdo

- Favela multiplayer com serviço dedicado `toque-war-favela.service` na porta UDP 3017 e entrada pelo menu online.
- RPG-7 e FIM-92 Stinger revisados em FPP/TPP/ADS, com PGO-7, retículas próprias, lock sonoro do Stinger e projéteis 3D.
- Favela urbanizada com concreto nas áreas construídas, terra preservada nas encostas e novos carros, lixeiras, pedras/entulho, postes, fibra e caixas.
- IA com pressão de objetivos, defesa quando todos os pontos estão controlados, resposta estratégica em 1,5 s e captura a partir de veículos ocupados.
- Áudio de armas suavizado por distância/direção e pacote de sons 30 mm dos APCs já presente na main.

## Integrações

- `ia/audio-continuity`
- `ia/favela-cimento-urbanidade`
- `ia/favela-multiplayer`
- `ia/favela-bot-pressure`
- `ia/bot-intensity-objectives` (conflito em `bot_director.gd` resolvido mantendo pressão da Favela e cadência global de 1,5 s)
- `ia/rpg-stinger-realismo`

FPP/TPP CollisionRig experimental permanece fora desta atualização.

## Gates

Os resultados finais de importação, QA, mapas, build assinada, preflight e verificação live serão registrados aqui após execução.
