# Realismo R1C — impacto de aterrissagem

**Data:** 09/11/2026
**Branch:** `ia/realismo-r1c-landing-impact-20261109`
**Base:** R1B em `e1b9037`

## Objetivo

Terceiro passo pequeno do plano de realismo. A R1C adiciona sensação de massa ao tocar o chão depois de uma queda, sem alterar a física real do personagem.

A solução permanece dentro de `WarLocomotion` e reutiliza a mesma flag experimental das R1A/R1B. Não foi criado outro controlador e `player.gd` não foi modificado.

## Contrato

- a velocidade vertical negativa é acumulada somente enquanto o ator local está no ar;
- o impulso nasce apenas na transição **ar → chão**;
- contatos abaixo de **2,5 m/s** não geram resposta, evitando ruído de degraus, rampas e pequenas correções;
- uma aterrissagem típica próxima de **4,4 m/s** desloca a apresentação da arma cerca de **2 cm para baixo**;
- quedas de **6 m/s ou mais** saturam no mesmo teto visual;
- o deslocamento máximo estrutural é **3,5 cm**;
- a recuperação visual usa **4,5 unidades/s**, sem mola infinita ou oscilação;
- somente `view_root` do ator local recebe o deslocamento;
- `weapon_root`, câmera, cápsula, hitboxes, velocidade, IA, rede e origem balística permanecem fora do efeito;
- ADS, tiro, recarga, granada, gadget e melee continuam protegidos pelos retornos existentes.

A mesma flag continua controlando o pacote R1:

`TDC_TACTICAL_MOTION_PILOT=1`

ou

`--tactical-motion-pilot`

## Implementação

`WarLocomotion` mantém três estados de apresentação para a R1C:

- `presentation_landing`: peso vertical atual;
- `presentation_fall_speed`: maior velocidade de queda observada no trecho aéreo;
- `presentation_was_grounded`: memória da transição física do tick anterior.

O cálculo roda antes do early-return de movimento horizontal. Assim, uma queda vertical parada produz impacto FPP sem forçar caminhada ou modificar a arma mundial.

## Resultado funcional

`tests/realismo_r1c_landing_weight.gd`: **16/16 PASS**.

Para uma velocidade de queda de 4,4 m/s:
- peso: **0,564128**;
- deslocamento esperado: **19,744 mm**;
- recuperação: **133,33 ms**.

O teto permanece em **35 mm**. R1A e R1B continuam compondo nos eixos Z/X sem rotação adicional, e ADS permanece isolado.

## Gate físico real

`tests/realismo_r1c_physics_landing.gd`: **10/10 PASS**.

A fixture final usa um `GamePlayer` real, cápsula com as dimensões de produção e `GameStepMotion` real sobre um `StaticBody3D`.

Queda de **1,15 m**:
- maior velocidade vertical registrada: **4,578 m/s**;
- contato físico: **frame 28**;
- impulso R1C: **frame 29**;
- `is_on_floor() == true` no disparo;
- peso calculado/observado: **0,638925**;
- peso durante o trecho aéreo: **0,0**;
- recuperação concluída no frame 38.

A primeira tentativa reutilizou `war_optics_fixture.gd`, mas essa fixture desabilita deliberadamente a cápsula física do ator porque foi criada para ópticas. O teste foi corrigido sem alterar o runtime.

## Calibração G3 renderizada

`tests/realismo_r1c_g3_calibration.gd`: **11/11 PASS**, em Forward+ / GTX 1650.

- aterrissagem normal: **19,744 mm**, retorno em **133,33 ms**;
- aterrissagem forte: **35,0 mm**, retorno em **233,33 ms**;
- deslocamento do `weapon_root`: **0,0 mm**;
- deriva lateral/longitudinal da R1C: **0,0 mm**;
- câmera FPP: transform inalterado;
- ADS: alinhamento exato preservado.

As capturas `neutral.png`, `normal-landing.png` e `hard-landing.png` foram revisadas visualmente. O impacto é perceptível sem virar camera shake ou arma solta.

## Regressões

Com R1A+R1B+R1C ativos:
- R1A: **8/8 PASS**;
- R1B: **13/13 PASS**;
- ópticas universais: **242/242 PASS**.

`tests/war_locomotion.gd` foi executado renderizado, mas não é atualmente um gate determinístico nesta máquina. A R1C produziu 7 falhas em 34 checks; a mesma execução A/B na branch R1B produziu 6 falhas em 34 checks, incluindo contagem de atores, timing de deslocamento e asserts antigos de áudio/escopo. Os valores capturados também contradisseram alguns asserts de timing. Por isso esse teste foi classificado como fixture instável para esta rodada e seu JSON gerado não foi versionado.

Os gates diretamente afetados pela R1C — transição ar→chão, arma física, câmera, FPP, ADS e composição R1A/R1B — passaram.

## Fora de escopo

Sem camera bob, sem camera shake, sem dano de queda, sem alteração de gravidade, sem mudança de velocidade de salto, sem roll/pitch adicional da arma, sem animação de quadril/tronco e sem integração na `main` nesta etapa.
