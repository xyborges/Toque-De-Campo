# Atualização 1.13.5 — Favela online, lançadores e combate

**Estado:** PUBLICADA em 05/11/2026 — build 92 (1.13.5).

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

## Publicação (05/11/2026)

- Build **92 / 1.13.5** preparada e assinada: `SIGNED_UBUNTU_RELEASE 92`; 11 artefatos autenticados.
- Instalação real do pacote assinado: **13/13 PASS**, incluindo boot protegido, DLL carregada e pacote inalterado.
- Preflight: **PASS**, `PREFLIGHT build=92 publicado=91` e `PREFLIGHT_OK build=92`.
- O primeiro deploy foi recusado porque o helper privilegiado instalado ainda não reconhecia o novo serviço da Favela. O helper foi atualizado com backup e verificação SHA-256.
- O guard de jogadores detectou depois um `status.json` BR cancelado e antigo cujo PID já podia ser reutilizado por outro processo. A correção `8a550cf` mantém o comportamento fail-closed para salas BR reais, mas confirma executável, `--br-room` e `room_id` antes de confiar no PID. A suíte `release_deployment.py` passou **24/24** após a correção.
- Deploy final: **PASS**, com `VERIFIED_READY build=92` e `DEPLOYED build=92 version=1.13.5`.
- Verificação live: **9/9 PASS**. O manifesto HTTPS é byte a byte igual ao assinado; `/opt/toque-de-campo/current` aponta para `build-92`; os seis serviços estão ativos; `toque-war-favela` possui PID próprio e socket UDP **3017**; hashes do executável Linux e PCK são idênticos ao manifesto assinado.
- Arquivo publicado do cliente: `releases/game-92-5e2905fc7475.zip`.
- Download interno: `https://192.168.101.24/`.
- Logs de evidência: `work/release1135-signed-install.log`, `work/release1135-preflight.log`, `work/release1135-deploy-guardfix.log` e `work/release1135-live-guardfix.log`.

O FPP/TPP CollisionRig experimental continua fora desta versão.
