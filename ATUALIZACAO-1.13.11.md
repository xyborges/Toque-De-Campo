# Atualização 1.13.11 — candidata de lançamento

**Data:** 11/11/2026. **Estado:** candidata em homologação, não publicada neste documento.

## Escopo fechado

- **Áudio:** correção dos disparos remotos de NPCs e jogadores, com atenuação de volume e agudos conforme a distância, preservando a lateralidade 3D. Commit `daff814` já integrado anteriormente na `main`.
- **Favela:** retirada integral da camada de 253 caminhos artificiais de terra junto às portas. Permanecem 4.313 casas, 18 vias e 217 degraus de escadarias existentes.
- **Bots:** LOD tático de decisões por distância, com opção de regressão `--war-bot-ai-lod-legacy`; sem alteração de física, dano ou frequência de replicação. Ganho de FPS **não garantido**.
- **Manifesto:** mapa Favela v32, 68 fontes e hashes reconciliados.

Não inclui Favela V2, Terrain3D, ProtonScatter, GDExtension/C++, escadaria em Z ou outras branches experimentais.

## Validação e publicação

Candidata isolada: `ia/release-11311-two-changes-20261110`.

- LOD determinístico: 27/27.
- Remoção das trilhas: PASS.
- Smoke da Favela: PASS, 49 rotas.
- Escape dos bots/APC: 10/10.
- Multiplayer ENet e carga: homologação em andamento.
- Preparação, assinatura, pré-verificação e implantação: pendentes até conclusão do gate.

A produção deve permanecer em 1.13.10/build 98 até o deploy protegido ser verificado.
