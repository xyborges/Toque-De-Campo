# Correções de ópticas — revisão da 1.13.0 (04/11/2026)

## Problemas identificados

- O teste anterior `8x applied` conferia apenas `magnification = 8.0`, não o tamanho do alvo renderizado. A descrição foi corrigida.
- A Hensoldt 4× tinha o plano da lente a 0,166 m da câmera; a 8×, a 0,115 m. Como o FOV usa a distância ocular-lente, a ampliação real relativa à mesma referência da própria óptica existia, mas a comparação de um alvo no mesmo lugar era apenas 69 px versus 50 px (1,38×). A intenção era 2×.
- A Hensoldt tinha aspecto de cilindros simples e apoio alto. O primeiro refinamento de cosméticos gerou anéis soltos e foi corrigido antes da conclusão.

## Alterações realizadas

1. `scenes/weapons/precision8x.tscn`: posição da ocular (`Eye`) calibrada em 0,376 m com lente (`Lens`) em 0,210 m. A distância ocular-lente torna-se 0,166 m, igual à Hensoldt 4×; o FOV permanece calculado pelo pipeline original, sem novos sistemas de mira.
2. `scenes/weapons/hensoldt4x.tscn`: base de montagem encurtada de 0,170 m para 0,126 m, garras e trilhos reposicionados para manter contato físico com o receptor.
3. `scripts/attachments/hensoldt_detail.gd`: acabamento de metal e borracha, ocular tubular, anéis em contato com o corpo, ajuste serrilhado, parafusos e pequenos indicadores. Três malhas com recursos reutilizados/cached, e distância de exibição de detalhes limitada a 85 m.
4. `tests/optical_magnification_measured_20261104.gd`: novo teste GPU que renderiza quadrado vermelho de 10 cm a 8 m, captura os `SubViewport` reais e mede pixels, nas quatro armas. A comparação usa a mesma posição, alvo e câmera do jogador.
5. `tests/optics_universal_validation_20261103.gd`: o teste de metadados não declara mais comprovar zoom visual.

## Resultados comprovados

| Condição | Hensoldt 4× | Telescópica 8× |
| --- | ---: | ---: |
| Largura do alvo sem magnificação (baseline de lente) | 12 px | 12 px |
| Largura com a lente ativa | 50 px | 100 px |
| Magnificação observada por pixels (aprox., sujeita à rasterização) | 4,17× | 8,33× |
| Proporção 8× / 4× no mesmo alvo | — | 2,00× |

Valores idênticos no FAL, AK, G3 e Sniper. Capturas em `work/magnification-<arma>-<optic>-<baseline|live>.png`; resultado em `work/optical-magnification-measured.json`.

## Regressões

- `tests/optical_magnification_measured_20261104.gd`: aprovado (renderização gráfica)
- `tests/optics_visual_capture_20261103.gd`: aprovado, capturas dos modelos e mira ADS
- `tests/optics_universal_validation_20261103.gd`: 242 validações headless e **294 validações com renderização real na GTX 1650**, nenhuma falha
- `tests/optic_catalog_validation.gd`: 38 validações, nenhuma falha
- `tests/prone_weapon_pose_validation.gd`: 1.126 validações, nenhuma falha
- `tests/war_spawn_attachment_crash_regression.gd`: 319 validações, nenhuma falha
- `tests/scoped_muzzle_regression.gd`: 490 validações, nenhuma falha

## Restrições de escopo

- O objetivo foi compatibilidade e validação local na versão de código 1.13.0. Não alterados dano, projétil, loot/spawns do BR, mapa ou servidor.
- Não foi executada partida real online com dois clientes conectados por DTLS nem benchmark FPS de 28 bots nesta revisão.
- Nenhuma build foi exportada nem publicada.
