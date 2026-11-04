# Revisão técnica P0/P1 — personagem único FPP/TPP (v2)

**Data:** 04/11/2026 — **Godot:** 4.7.2 — **versão local:** 1.13.1.  
**Status:** revisão incorporada e primeira bateria **P0 iniciada**, sem alterações nos scripts de gameplay. **NÃO liberado para P2, NÃO publicado.**  
**Plano vigente:** [FPP-TPP-CORPO-UNICO-PLANO-20261104.md](FPP-TPP-CORPO-UNICO-PLANO-20261104.md).  
**Plano-pai:** [REALISMO-TATICO-PLANO-SQUAD-20261104.md](REALISMO-TATICO-PLANO-SQUAD-20261104.md).  
**Motivação:** auditoria externa do plano contra o código apontou dependências ocultas na mira, câmera, LOD de hitbox, ópticas e testes. Os cinco pontos foram confirmados no código em 04/11/2026.

## 1. P0 — evidências reais obtidas

| Verificação | Resultado da execução headless | Interpretação |
|---|---|---|
| `tests/scoped_muzzle_regression.gd` | **Falhou: 326/490 verificações; erro máximo ~0,593 m** | A comparação FPP vs cano físico de FAL/AK está fora da tolerância; não tratar paridade existente como aprovada. O teste ainda usa `view_root`, e precisa ser desmembrado entre erro do teste e erro verdadeiro de pose |
| `tests/optics_universal_validation_20261103.gd` | Passou: **242/242**, `rendered=false` | Compatibilidade *headless* da configuração atual, NÃO comprova renderização PiP real nem novo sistema sem `view_root` |
| `tests/prone_weapon_pose_validation.gd` | Passou: **1126/1126**, maior escala de antebraço 1,2603 | Regra atual de prone e armas no BR continua passando; precisa manter esse gate na migração |
| `tests/true_fpp_p0_g3_baseline.gd` (novo) | Primeiro ensaio: 3 variantes G3, tiros aceitos tanto hip FPP quanto hip TPP; ADS com preferência TPP dá câmera **efetiva FPP** | Captura `camera_origin`, `muzzle`, apresentação visível e `shot_packet`; relatórios em `work/fpp-tpp-p0-20261104/g3-baseline.json` |
| G3 duplicado | A FPP contém `Imported_g3` em `view_root` e o mundo contém `Imported_g3` em `weapon_root` | A duplicação existe no runtime e não é somente problema conceitual |
| Erro G3 FPP (cenário de referência) | Diferença inicial FPP copy vs muzzle físico: **~0,264 m**, com arma sem mira óptica | Uma evidência adicional da divergência na pose atual; não validar por snapshot de modelo oculto em TPP |
| Câmara TPP em hip | Distância de câmera ao pivô do olho ~**4,09 m** no fixture; `WarPlayer.shot_camera_valid` tolera envelope da mola até 4,4 m com raycast | A origem do raio muda mesmo que arma/muzzle sejam um único nó; não confundir preferência com perspectiva efetiva |
| Mecanismo G3 | `G3Model.create()` cria nó `ChargingHandle`. `GameReloadPose.apply()` busca `ChargingHandle` somente no FAL e `SlideAssembly` para os demais | O manete do G3 fica **sem deslocamento** na recarga atual; falha funcional visual de base, independente de FPP/TPP |

**Reprodutibilidade:** P0 foi executada com `Godot_v4.7.2-stable_win64_console.exe --headless --path <root> --script <test>`. Logs por teste em `work/fpp-tpp-p0-20261104/`; relatórios dos testes legados gravados em `work/`. O resultado da execução `scoped_muzzle_regression` é **vermelho**, não foi corrigido nem suavizado.

**P0b (parcial) avançada em 04/11/2026:** concluídos no fixture G3 seis cenários de cobertura FPP/TPP, quatro capturas gráficas Compatibility e comparação controlada de hitboxes a até 1700 m. [Relatório com evidências e ressalvas](FPP-TPP-P0B-RESULTADOS-20261104.md). **P0 ainda não terminada:** faltam dois clientes ENet reais, impacto/dano com balística completa, 28 bots e p95/p99, hitbox em listen/dedicated e ragdoll. Testes legados `camera_collision.gd` e suites de rede standalone ficaram inconclusivos devido às fixtures e não aprovam o gameplay.

## 2. Achado principal: câmera define alvo, cano define origem

`scripts/player.gd::fire()` captura `camera.global_position` e `-camera.global_basis.z`; `scripts/main.gd::_server_accept_shot()` usa raycast câmera->alvo e calcula `shot_direction = (alvo - muzzle).normalized()`. Existe sweep pivô/olho->cano (`eye`->`origin`), mas **isso não prova** que os dois disparos têm mesmo impacto ou que barreiras entre o cano e o alvo são tratadas identicamente. O servidor valida `direction` contra pitch/yaw e `WarPlayer.shot_camera_valid()` valida envelope de ombro/cobertura da câmera.

**Decisão de arquitetura (P1, com migração controlada):**
- **Estado atual P0/P2a compatibilidade:** manter a balística câmera->alvo existente. Medir e documentar disparos divergentes em FPP/TPP; NÃO alegar hit parity e NÃO ajustar dano/dispersão/cano para esconder erro. Os novos rigs devem continuar atirando pelo `muzzle` do mundo.
- **Objetivo final P1-BALÍSTICA, a entrar somente sob flag própria depois de testes:** padronizar um **`LogicalAimOrigin` (olho lógico atrelado ao corpo)** e um **`LogicalAimDirection` (yaw/pitch aceitos)**, comuns à FPP e TPP para o mesmo `PoseState`. A posição da câmera passa a ser observação, não a fonte do alvo para o gameplay. O servidor reconstitui direção do estado validado, em vez de confiar cegamente no raio recebido.
- **Dois raycasts + trajetória:** (A) `logical_eye`->ponto visado para determinar alvo e visibilidade real da cabeça; (B) `muzzle`->ponto visado para impedir o cano de atravessar parede/cobertura; **também** varrer `logical_eye`->`muzzle` para impedir apontamento através de parede próxima. Em caso de bloqueio, resolver impacto na obstrução real mais próxima, com tolerância sem causar falso bloqueio de borda. Projetil sempre sai do muzzle e percorre a balística existente.
- **Retículo TPP honesto:** exibir a interseção projetada do **aim lógico**, não um retículo artificial que promete acerto por cima de muros. Se o retículo estiver na parede, mostrar/posicionar consistentemente. A câmera TPP pode continuar sobre o ombro, mas não concede visão de tiro a partir de 4 m atrás.
- **Compatibilidade:** essa mudança altera a jogabilidade de TPP, então precisa de testes e decisão explícita depois da P0, podendo ficar desativada enquanto só a geometria do corpo é unificada. Não misturar rollout com alterações de ADS, recoil, precisão ou rede.

**Teste de aceite de balística:** `same PoseState + same world + FPP/TPP` => ambos produzirem mesmo `LogicalAimTarget`, mesma posição de muzzle, mesmo `shot_packet.origin/direction/blocked` e mesmo impacto/dano dentro da tolerância balística determinística. Cenários: chão aberto, parede a 20 cm do cano, quina esquerda/direita, janela, mureta, corpo abaixado e prone, alvo atrás de cobertura que a câmera TPP enxerga mas o olho lógico não, e entrada/saída de ADS. Auditar também `shot_camera_valid` e `aim_level` para não abrir exploração de rede.

## 3. P1-Pose — hitboxes são física, LOD é só visual

`modes/war/scripts/player.gd::_animate_walk()` limita frequência para atores não locais **quando existe câmera/observador local**: ~30 Hz a menos de 80 m, ~15 Hz abaixo de 250 m e ~8 Hz além; o método pode retornar **antes** de `GamePlayer._animate_walk()`. As `Area3D` de acerto são filhas das malhas/articulações `scripts/player.gd::_add_hit_region()`. Portanto pular pose não é automaticamente seguro para hitbox. Num servidor totalmente headless, a condição de LOD pode não ocorrer da mesma forma; em listen server ou com câmera local ela pode ocorrer.

**Contratos obrigatórios:**
1. Separar `CollisionPose` e `PresentationPose`: servidor e qualquer ator que possa ser atingido atualizam o estado **mínimo físico necessário** (articulações com hitbox, peito/cabeça/ombro/antebraço/perna, inclinação, altura e muzzle) por **physics tick fixo**, sem depender da câmera ou distância do observador. Se for otimizar física, medir custo e manter consistência de posição por membro.
2. `PresentationPose` pode ter frequência reduzida por distância (8–30 Hz ou outra medição) e interpolar visualmente, **sem congelar o ancestral das `Area3D`**. Separar nós de apresentação daqueles que movem áreas de hit quando necessário, ou sempre resolver pivôs de colisão em frequência constante sem resolver malha/cor/material.
3. A **identidade do observador não pode modificar o hitbox** no mesmo estado lógico. Trocar câmera FPP/TPP, afastar/retornar o observador ou mudar preset gráfico não muda transform das regiões de acerto nem geometria de acerto do disparo.
4. Bots, jogadores, host em listen server e dedicated server devem executar o mesmo contrato físico. O visual simplificado de 1.700 m pode continuar leve, sem baixar tick de IA/combat/physics.

**Teste LOD/collision:** 3 atores x 5 distâncias (10, 70, 150, 300, 1700 m) x 3 pontos de vista (FPP, TPP, câmera espectador), standing/crouch/prone, servidor headless e listen server. Comparar `Hit_head/chest/armL/armR/legL/legR` e cano em `server_tick` fixado; erro esperado **próximo de zero** ao trocar só observador; permitir apenas interpolação da apresentação remota, nunca da hitbox autoritativa.

## 4. Dependências corrigidas: nova ordem de implementação

| Gate | Entrega | Pode ser liberada sem... | Bloqueio para avançar |
|---|---|---|---|
| **P0a — feito parcialmente** | Auditoria estática + testes atuais + G3 baseline headless | alterar runtime | não concluir P0 sem cobertura, screenshot e rede |
| **P0b — pendente** | Cena controlada de muro/quina/janela, vítima, G3, câmera efetiva, hitboxes de perto/longe, duas máquinas e FPS | mudanças em arma | congelar logs/capturas e confirmar casos atuais |
| **P1a** | Contrato `PoseFrame` e `CollisionPose` / `PresentationPose`, cache por tick e estado de recarga | trocar rig ou mexer na balística | hitbox independente da distância/câmera |
| **P1b** | Contrato do aim lógico comum **especificado e testado sob flag**, com baseline atual preservado | ativar imediatamente para jogadores | blocked/camera origin/real shot aceite iguais ao esperado |
| **P2a + P3a** | Piloto **G3 sem óptica, mira de ferro, Guerra**. Trocar camada de visibilidade da cabeça e posicionamento de câmera, arma real e mãos reais como única pose | refatorar `weapon_optics` global | câmera/render G3 já funcionando, ADS sem PiP e TPP sem `view_root` |
| **P2b + P4** | Adaptador PiP para **lente real** do G3. Migrar `_view_scope()`, `update()`, cull_mask e material do SubViewport para `weapon_root` | mexer em AK/FAL/BR | 4x/8x reais medidos, sem recursão e sem FPP copy |
| **P2c** | Eliminar de vez cópias G3 na FPP e trocar apenas câmera | remover adaptadores de outras armas | 20 alternâncias durante reload, optics, prone, near-wall, sem instância nova |
| **P5** | AK, FAL, Glock, sniper, equip, recargas, óticas | mudar BR fists/melee/gadgets | regressões de cano/assentos/rede |
| **P6** | BR fists, granadas, lançadores, binóculos, gadgets, melee, ragdoll/veículos | migrar Skeleton3D | testes por classe/modo e rollback |
| **P7+** | Rig esquelético experimental, otimização final e eventual release | reescrever física do jogo | 28 bots, 40 BR, vídeo FPP/TPP, p99, rede real |

**Não fazer:** P2 G3 sem a infraestrutura de visibilidade P3a; remover `view_root` antes da migração PiP P4; habilitar `LogicalAimOrigin` para multiplayer sem teste anti-cheat; modificar o modelo G3 só para obter aprovação de diferença visual em um teste antigo.

## 5. Matriz de regressão revisada

- **`scoped_muzzle_regression.gd`:** o caso atual FAL/AK usa `view_root`. No novo teste não exigir que a cópia exista; comparar marker REAL, pose visual do cano/arma, cano autoritativo remoto e pacote aceito, mantendo o teste legado para comparação até o adaptador migrar. Incluir G3 com mira de ferro e G3 com PiP.
- **`optics_universal_validation_20261103.gd`:** o caso atual exige `Scope4x` na cópia, então primeiro adaptá-lo à condição da flag e depois exigir **exatamente uma óptica real**, abertura/fechamento de SubViewport e lentes 4x/8x realmente ampliando. Provas devem incluir Compatibility renderizado, não apenas `headless`.
- **ADS TPP:** `modes/war/scripts/player.gd::_update_view()` força a câmera efetiva FPP em `iron_sights` e `weapon_optics.presented()`. Registrar tanto `game.third_person` (preferência) quanto **`effective_view`** derivado do pai/offset da câmera. Alternar preferência durante ADS e concluir paridade é **teste inválido** se ambas as amostras continuarem FPP.
- **Balística:** `game._server_accept_shot` precisa ser interceptado em fixture e gravar `shot_packet` por `life_id/sequence` para comparar `origin`, `direction`, `blocked`, `impact` e dano. Repetir em rede com observador remoto e cobertura próxima.
- **Membros:** testar `Hit_* ` e `muzzle` em distância independente do observador e nível de LOD de apresentação, inclusive listen server/host.
- **Manete G3 — dívida registrada:** `scripts/g3_model.gd` cria `ChargingHandle`, mas `scripts/reload_pose.gd::apply` procura `ChargingHandle` se `fal`, caso contrário `SlideAssembly`. G3 não move o manete; criar teste de estado `mechanism>0` exigindo deslocamento G3 após a correção **em pacote próprio**, sem atribuir o bug à unificação de câmeras.
- **Anti-cheat/perspectiva:** `WarPlayer.shot_camera_valid()` aceita envelope lateral/traseiro da câmera de ombro até 4,4 m e raycast de pivot para câmera. Testar o envelope em conjunto com o aim lógico final; não confiar em origem de câmera não verificada.

## 6. Fontes, scripts e execução

**Fonte primária:** repositório local, `scripts/player.gd::fire`, `scripts/main.gd::_server_accept_shot`, `modes/war/scripts/player.gd::_update_view/_animate_walk/shot_camera_valid`, `scripts/player.gd::_add_hit_region`, `scripts/g3_model.gd`, `scripts/reload_pose.gd::apply`, `scripts/weapon_optics.gd::update`, `tests/scoped_muzzle_regression.gd`, `tests/optics_universal_validation_20261103.gd`.

**P0 teste criado sem mudar jogo:** `tests/true_fpp_p0_g3_baseline.gd`. Evidências em `work/fpp-tpp-p0-20261104/`. Executar sempre no projeto real e salvar stdout/exit code; fixture cria cenas temporárias e não altera persistência de jogo.

**Como continuar:** primeiro completar P0b e isolar falha de `scoped_muzzle_regression` (cópia FPP antiga versus cano real), além do teste G3. Somente depois abrir P1a. Evitar scripts compartilhados que outras sessões estejam editando. Registrar diff, backups e pass/fail reais. **Não publicar.**
