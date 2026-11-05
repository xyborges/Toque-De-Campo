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

- Godot 4.7.2: importação completa **PASS**.
- RPG-7/Stinger: `launcher_realism_qa.gd` **PASS**; inspeção FPP/TPP/ADS e projéteis já preservada na branch integrada.
- Favela urbanidade: **PASS**.
- Pressão dos bots: primeiro ensaio detectou cobertura lateral interrompendo o avanço; corrigido em `aa93669`. Repetição final **PASS**, incluindo assalto com inimigo visível e defesa sob controle total.
- Intensidade de bots/veículos: **PASS**.
- Captura em veículos ocupados: **PASS**.
- Menu Favela: **22/22 PASS** após regenerar a identidade preparada para manifesto v10.
- Smoke visual da Favela: **PASS**.
- Runtime Favela com 28 bots: **PASS**.
- Áudio open-air com mixer 3D nativo: **PASS**.
- Áudio espacial: **28/28 PASS**; medições transitórias não foram versionadas.
- Empacotamento/deploy estático: **PASS**.
- Mapas: Afegão, Deserto, Escritório e Naval **PASS**; Ucrânia regenerada para v19 e validada **PASS** com 802.579 patches de grama. Afegão mantém o aviso conhecido de 1/162 âncoras rejeitada.
- Favela ENet/DTLS: servidor local + 2 clientes **PASS**.

Aguardando apenas build assinada, preflight e verificação live no servidor para marcar como publicada.
