# Atualização 1.13.11 — PUBLICADA (build 99)

**Data:** 11/11/2026. **Estado:** publicada no servidor Ubuntu, verificada em produção. Fonte integrada na `main` local: `385e83b`. Candidata homologada: `4bd1d88`.

## Conteúdo da atualização

- **Áudio 3D:** correção dos disparos remotos de NPCs e jogadores, com atenuação de volume e agudos conforme a distância, preservando a lateralidade real da fonte. Commit `daff814` já integrado à `main` antes desta release, mas não presente na antiga build 98.
- **Favela:** remoção da camada de 253 caminhos artificiais de terra entre as portas e as ruas. Permanecem 4.313 casas, 18 vias, 217 degraus de escadas existentes e 49 rotas.
- **IA dos bots:** LOD tático de decisões por distância, ativo por padrão no modo Guerra, com rollback `--war-bot-ai-lod-legacy`; física, dano, colisões e cadência de replicação não foram alterados. **Não há comprovação de melhoria geral de FPS** em testes gráficos A/B.
- **Manifesto da Favela:** v32, 68 fontes e hashes reconciliados com o código publicado.

Nenhuma branch de Favela V2, Terrain3D, ProtonScatter, C++/GDExtension ou escadaria em Z entrou nesta release.

## Homologação conjunta

- Godot 4.7.2: `BOT_AI_LOD_QA` **27/27 PASS**.
- Remoção de caminhos de terra: **PASS**, zero malhas antigas geradas.
- Smoke completo da Favela: **PASS**, 49 rotas, 11.624 colisões, 4.313 casas.
- IA de escape e reação a APC: **10/10 PASS**.
- Favela 28 bots — pressão nos objetivos e defesa: **PASS**.
- Multiplayer ENet/DTLS: **servidor + 2 clientes**, cada cliente confirmou 2 humanos e 28 bots, `FAVELA_ENET_PASS`; sem falhas no relatório de QA. A medição do servidor no encerramento reporta 0 atores após limpeza; os clientes confirmaram a carga durante a sessão.
- Áudio remoto `daff814`: 289/289 checks ENet e 269/269 regressões do mixer registrados na branch original; código de áudio inalterado na candidata.
- Manifesto Favela final: `FAVELA_MANIFEST MATCH version 32 inputs 68`.

## Publicação protegida Ubuntu

- Preparação oficial: `SIGNED_UBUNTU_RELEASE 99`.
- Instalador assinado: **13/13 verificações**, startup protegido Windows com DLL carregada, sem modificação dos arquivos.
- Preflight: `PREFLIGHT build=99 publicado=98`, `PREFLIGHT_OK build=99`.
- Ativação: `VERIFIED_READY build=99`, `DEPLOYED build=99 version=1.13.11`, exit 0.
- Auditoria ao vivo: **8/8 PASS**, manifesto HTTPS idêntico ao local assinado, server-manifest 99, symlink `/opt/toque-de-campo/releases/build-99`, hashes do Linux EXE/PCK corretos, serviços `toque-war`, `toque-war-afghan`, `toque-war-favela`, `toque-br`, `toque-naval`, `toque-pvp` ativos; UDP 3017 ouvindo.
- Arquivo cliente: `releases/game-99-53d6598ff1ea.zip`.
- Endereço de acesso na rede/VPN: https://192.168.101.24/

## Registros locais de auditoria

- `work/release11311-prepare.log`
- `work/release11311-signed-install.log`
- `work/release11311-preflight.log`
- `work/release11311-deploy.log`
- `work/release11311-live-verify.log`
- `work/verify_release11311_live.py`
- `work/release11311-qa/` (candidata isolada)

O deploy não significa que a meta de 60 FPS com GTX 1650 e 28 bots foi atingida. A configuração antiga de agendamento dos bots continua disponível para comparação ou reversão.
