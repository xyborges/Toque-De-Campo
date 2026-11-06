# Plano técnico — Personagem único FPP/TPP (True First Person)
**Data:** 04/11/2026  
**Projeto:** Toque de Campo — auditoria original na 1.13.1; base de integração atual 1.13.3, Godot 4.7 / GL Compatibility
**Status:** P1b–P1j implementados e testados em branch isolada; **P1g desligado por padrão, P2 pendente, sem novo release**
**Plano-pai:** `docs/REALISMO-TATICO-PLANO-SQUAD-20261104.md`  
**Referência ambiental:** `docs/AFEGANISTAO-REFERENCIA-SINAI-TRILHAS-20261104.md`

> **P1k — atualização de 06/11/2026:** [otimização e evidências](FPP-TPP-P1K-OTIMIZACAO-20261105.md) na branch `ia/fpp-p1k-retomada`. Captura tipada e buffers de colisão por ator preservam 1.200 poses e as nove suítes funcionais; ENet/DTLS local passou 19/19. **Desempenho continua reprovado:** cinco pares com 28 atores observaram +73,3% na mediana e +64,9% no p99; o A/A também excedeu o ruído permitido. P2a, mapa completo/clientes exportados e merge na main permanecem pendentes. Os estados abaixo registram o histórico anterior.

> **ESTADO ATUAL (04/11/2026):** [integração e QA da P1 sobre 1.13.3](FPP-TPP-INTEGRACAO-1133-QA-20261104.md), branch `ia/fpp-integracao-1133`, commit-base `9e5d741`. P1f usa olho lógico para mira FPP/TPP; P1g tem CollisionRig independente opt-in (31/31 verificações); P1i validou dano por membro e ragdoll (24/24); P1j passou ENet/DTLS com servidor 15/15, atirador 2/2 e vítima 2/2. Zeragem (58/58) e ópticas headless (242/242) permaneceram verdes na integração. **Ainda bloqueado:** custo de 28 atores/bots, fallback de ações especiais com LOD visual, mapa completo/clientes exportados e a P2 de corpo/câmera únicos. Nenhuma publicação feita por esta branch.
>
> **As notas P0/P1a/P1b abaixo são histórico do diagnóstico inicial**, não o estado atual do projeto.
>
> **P1b iniciada com protótipo separado:** [CollisionRig físico isolado e validado](FPP-TPP-P1B-COLLISION-RIG-PROXY-20261104.md), 16 regiões e marcador de cano com correspondência de transform 0 m nas três posturas, sem dupla colisão. Ainda espelha pose visual; próximo gate é solver puro independente do render e teste de desempenho, antes de passar hitboxes reais para o proxy.
>
> **P1a — experimento leve de 04/11/2026 encerrado:** [relatório](FPP-TPP-P1A-COLLISION-LITE-EXPERIMENT-20261104.md). Abordagens Lite e por eventos corrigiram a inconsistência do teste de postura, mas pioraram a média ou o p99 da CPU com 28 atores; **ambas foram revertidas no gameplay**. Foi criado `collision_pose_state.gd`, com captura e comparação física de 13–16 regiões e cano; teste próprio passou nas três posturas. A próxima peça precisa ser um **CollisionRig autônomo sem MeshInstance3D**, não mais um remendo no LOD existente.
>
> **P1a — piloto de física avaliado em 04/11/2026:** [relatório e testes](FPP-TPP-P1A-PILOTO-20261104.md). Host com `--true-fpp-p1a-authority`: 13 hit regions coerentes em cinco distâncias, mas atualização integral em 28 atores aumentou custo médio da pose de 3,39 ms para 7,53 ms por lote. **Flag desligada por padrão**; ainda falta o solver de `CollisionPose` mais leve para permitir avanço de P2 sem regressão de FPS.
>
> **RESULTADOS P0b 04/11/2026:** seis casos de cobertura G3, quatro capturas reais no Compatibility e prova controlada de risco de hitbox ao suspender pose em 10–1700 m; divergências concretas FPP/TPP em quina direita e janela. Ver [FPP-TPP-P0B-RESULTADOS-20261104.md](FPP-TPP-P0B-RESULTADOS-20261104.md). Os testes não certificam desempenho/online; sem mudança de gameplay.
>
> **REVISÃO TÉCNICA v2 — 04/11/2026, obrigatória para implementação:** a análise de dependências e a P0 estão documentadas em [FPP-TPP-REVISAO-P0-20261104.md](FPP-TPP-REVISAO-P0-20261104.md). **Essa revisão prevalece** sobre a ordem original P2/P3/P4 e sobre qualquer interpretação de que apenas um `muzzle_marker` gera disparos equivalentes. **Nova ordem:** P0 medição -> P1 contrato de câmera/mira/pose física -> P2a câmera FPP real com visibilidade e G3 sem óptica -> P2b ótica PiP em arma real -> P2c remoção final da cópia do G3 -> demais armas. Não atualizar código de gameplay sem os gates de colisão, câmera efetiva e testes automatizados.

## 1. Decisão de projeto

**FPP e TPP precisam mostrar A MESMA ação, do MESMO personagem, com UMA arma de mundo, UM conjunto de mãos/articulações, UM relógio de animação e UMA origem balística autoritativa.** Preferência final: sistema *true first person* de corpo completo, que reposiciona a câmera e aplica uma política de visibilidade local, **sem criar uma segunda arma e braços de gameplay**. Uma compensação apenas óptica ou um proxy visual de transição só pode existir se compartilhar o mesmo PoseFrame e não afetar tiros, hitboxes ou tempos; deve ser temporário e medido.

Duas câmeras com apresentação diferente podem existir; **dois estados de personagem ou duas mecânicas de recarga NÃO**. Substituir `view_root` diretamente é proibido até os casos de ótica, granada, BR fists, melee e lançamento terem substitutos validados.

## 2. Diagnóstico do código e causas identificadas

| Área | Local auditado | Situação e risco |
|---|---|---|
| Corpo/colisões | `scripts/player.gd` | `GamePlayer` é `CharacterBody3D` e cria avatar por partes, `avatar_parts` + `hit_regions`; dados reais não devem acompanhar um mock de câmera |
| Corpo/pega da arma | `modes/war/scripts/human_rig.gd` | `WarHumanRig.pose()` resolve ombro-cotovelo-punho para a arma do mundo; reaproveitar o solver em vez de reimplementar para FPP |
| Apresentação FPP | `scripts/player.gd::_refresh_view_weapon` | Duplica `weapon_root` para `view_root` na câmera, cria duas mãos e dois antebraços; usa `duplicate(7/15)` e pode duplicar materiais/pivôs especiais |
| Câmera/comparação | `scripts/player.gd::_update_view/_update_camera_collision` | Esconde braços e arma real em FPP e mostra cópia; em TPP volta a mostrar mundo. `camera_close` usa FPP temporária contra parede |
| Poses duplicadas | `scripts/player.gd::_update_ak_view_hands`, `_update_sniper_view_hands`, `_update_first_person_hands` | Mãos FPP em espaço da câmera usam anchors próprios, diferentes das mãos do corpo: principal origem de discrepância visual |
| Recarga | `scripts/reload_pose.gd`, `scripts/player.gd::_update_weapon_pose` | Já existem timers e poses compartilhados, mas o resultado é aplicado **duas vezes**, no modelo do mundo e na cópia. Proibir drift de tempo e efeitos duplicados |
| Postura/ordem | `scripts/infantry_pose.gd`, `modes/war/scripts/stance.gd`, `modes/war/scripts/locomotion.gd` | Mirar, agachar/deitar, deslocamento e lean alteram braços e câmera em passos distintos; `_animate_walk()` inclui correções tardias de corpo. Centralizar ordem |
| Câmera do Guerra | `modes/war/scripts/player.gd` | Usa `SpringArm3D` TPP com colisão, modo FPP para ADS/ópticas, ocultação local e apresentação de lançador duplicada |
| Lançador | `modes/war/scripts/player.gd::_refresh_view_weapon` | RPG/Javelin herdam cópia `launcher_model.duplicate()` e braços especiais; unificar após G3/rifles |
| Punhos BR | `modes/battle_royale/scripts/player.gd::_refresh_view_weapon/_pose_fists` | Outra pose independente na FPP, inclusive socos; não eliminar até haver gesto único verificado |
| Granada | `scripts/player.gd::_update_grenade_pose` | `GrenadePresentation` cria braço, mão, granada separados na câmera; risco de divergência no arremesso e interação |
| Binóculos/medicina | `modes/war/scripts/player.gd::_utility_pose/_binocular_pose` | Apresentações específicas na FPP; manter os mesmos estados e marcadores de pegada |
| Lentes ópticas | `scripts/weapon_optics.gd` | `SubViewport` PiP, cópia de lente e máscara `PRESENTATION_LAYER=1<<18`. `_view_scope`, `prepare_copy`, `update` são dependentes de `view_root`: precisam migrar juntas |
| Balística | `scripts/player.gd::get_muzzle_position/present_fire/shot_camera_valid` e Guerra `_server_accept_shot` | Um único `muzzle_marker` real deve continuar alimentando física/servidor. Trocar câmera jamais aumenta alcance do tiro nem atravessa paredes |
| Multiplayer | `modes/war/scripts/game.gd::server_player_state`, `war_posture_request` e BR `game.gd` | Snapshots validam pitch, lean, postura, vida, sequência; preservar protocolo e eventos autoritativos. Não transmitir transform de cada osso |
| Ragdoll | `scripts/death_ragdoll.gd` | Montagem assume `avatar_parts` e malhas separadas; migrar `Skeleton3D` sem adaptar o construtor quebra corpo e equipamento |
| Áudio/locomoção | `modes/war/scripts/soundscape.gd` e `locomotion.gd` | Sons por contato e distância percorrida; eventos FPP/TPP não podem duplicar passos/recargas |
| Performance | `work/performance-pilot-20261103/RELATORIO.md` | Alvo GTX 1650 com 28 bots ainda NÃO está aprovado para 60 FPS. Não usar atualização completa de esqueleto para cada bot a cada render tick |

A causa não é simplesmente uma posição ruim da câmera: existem **múltiplas árvores visuais** e **solvers de mão diferentes**. Ainda assim, a solução final é muito mais simples que conservar duas versões completas: uma pose autoritativa e câmeras consumidoras dessa pose.

## 3. Arquitetura-alvo e seus contratos

```text
GamePlayer (CharacterBody3D) — estado do jogo e colisão
├── CharacterMotionState — posição, velocidade, postura, vida, lean, ADS
├── PoseController — ÚNICO relógio/eventos (physics-tick + interpolação local)
│   ├── PoseFrame — corpo, quadril, tronco, ombros, braços, mãos, pernas
│   └── WeaponAction — equip/reload/throw/shoot/medic, sequência + progresso
├── AvatarWorld — MESMO corpo físico, regiões de hit e ragdoll
│   ├── BodyRig (pivôs existentes; Skeleton3D opcional em fase futura)
│   └── HeldWeapon (UMA instância REAL)
│       ├── GripRight / SupportGrip / Magazine / ChargingHandle
│       ├── AimReference / EyeAnchor / RearIron / FrontIron
│       └── Muzzle (origem balística real)
└── CameraController — visualização, NÃO autoriza disparo
    ├── FPS: cabeça/olhos + head exclusion por render mask
    └── TPS: SpringArm3D com colisão e shoulder swap
```

**Invariantes implementáveis:**
1. `weapon_root` e `muzzle_marker` são os **mesmos Node3D** no começo, durante e após trocar de FPP para TPP; `view_root` não tem arma de gameplay.
2. `PoseFrame` é calculado uma vez por tick/estado, **independente do modo de câmera**; com o mesmo estado/tempo -> mesmo resultado. O rig pode interpolar para render sem mudar o resultado autoritativo.
3. Ambos os punhos usam os mesmos `GripRight/SupportGrip` do modelo real. A mão de apoio sai do guarda-mão **apenas se o evento de recarga exigir**; ela não reaparece em outra posição só por mudar câmera.
4. `weapon_muzzle.world_transform` é único; tiros locais previstos e aceitos devem apontar para a mesma direção validada. A FPP vê o *mesmo projétil*: não aplicar 'barrel offset cheat' que altera o acerto.
5. O servidor controla `hp`, `ammo`, `reload_left`, `grenades`, `life_id`, `stance`, `weapon_id` e hit results; a câmera é apenas uma escolha de exibição do cliente.
6. O áudio de uma ação é acionado **uma vez** por `life_id/event_id/weapon`, não uma vez por câmera.
7. Uma animação visual não move o collider de disparo de forma diferente no servidor e cliente, nem pode criar hitbox defasada.
8. Mesmo material de roupa/luva, acessórios, orientação de carregador, estado de ferrolho e cor de skin em FPP e TPP. Não duplicar materiais mutáveis sem necessidade.
9. O modelo de mundo sempre é exibido corretamente aos outros jogadores. Mudanças de culling nunca ocultam remotamente sua cabeça ou arma.
10. Modos BR, Guerra, Offline e demais modos não devem herdar alterações de forma automática sem testes próprios.

## 4. Fluxo exato de atualização por física e render

```text
[Input local / comandos recebidos]
        ↓ validação de estado, life_id e sequência
[Simulation tick]
  1. Consumir movimento/postura/lean/ADS aceitos.
  2. Atualizar CharacterBody3D, cápsula, posição e estados de saúde.
  3. Atualizar relógio único de arma e recarga, com equip/cancel/retomar.
  4. Construir PoseFrame (gait, direção, tronco, cabeça, braços).
  5. Resolver posição do HeldWeapon e da ótica de mundo.
  6. Resolver mãos pela mesma empunhadura (IK/WarHumanRig).
  7. Resolver cápsula/regiões de hit e ponto real do cano.
  8. Carimbar PoseFrame com life_id, tick e event_seq.
        ↓
[Render / cliente]
  9. Interpolar pose entre duas amostras sem mudar autoria do tiro.
 10. Escolher perspectiva FPP/TPP e render mask, SEM reexecutar IK.
 11. Atualizar lente PiP (quando ADS ativo) a partir da ótica REAL.
 12. Exibir VFX e áudio deduplicados por evento.
```

**Nota de implementação:** não assumir ordem de `_process`/`_physics_process` na qual a câmera pode mirar com uma pose do quadro N e a arma estar no N-1. Definir passagem explícita `finalize_pose_before_weapon_fire()`/cache de frame e invalidar quando pitch/recoil/ADS/postura alterarem a pose entre ticks. Atualmente `get_muzzle_position()` chama `_update_weapon_pose()`; o novo caminho deve continuar retornando um cano coerente em tiros disparados entre updates físicos. A pose de hit e colisão não é interpolada só pelo render.

### Estado mínimo (contrato, não código implementado)

```text
PoseState {
  actor_life, server_tick, weapon_id, stance, ADS_level,
  aim_yaw, aim_pitch, lean,
  locomotion_local_xz, gait_phase,
  action_kind, action_sequence, action_start_tick,
  reload_left, reload_total, recoil_impulse_id
}
```

Reutilizar pacotes e campos existentes. `action_start_tick` e `gait_phase` só precisam ser transportados se testes provarem que clientes remotos não conseguem reconstruí-los de eventos/snapshots existentes. Nunca RPC por osso/quadro. Em caso de perda de pacote, reconstruir visual de `life_id + action_sequence + progress`, sem reproduzir sons de evento antigos.

## 5. Câmera de primeira pessoa: a parte que NÃO é apenas movê-la

**Objetivo:** câmera no ponto de observação da cabeça, mesmo modelo corporal e mesma arma; ocultação **local para a câmera**, não `avatar.hide()` global.

- Usar `Camera3D.cull_mask` e `VisualInstance3D.layers` para não renderizar o crânio/face/capacete do personagem local em FPP, **sem desativar hitbox, cabeça, sombras ou render para os demais**. A cabeça deve ser separável da malha do corpo (nó ou superfície isolada), caso contrário é inviável ocultá-la apenas por camada.
- Testar a posição da câmera no osso/pivô **olho** com correção independente de inclinação. Fazer o crânio acompanhar mira sem fazer a câmera oscilar absurdamente com a animação: compensação visual do observador é permitida, nunca dos impactos ou cano.
- Evitar a câmera dentro de torso/colete em `prone`, `crouch`, `lean`, escadas, aterros e debaixo de telhados. Usar solver de obstrução existente `CameraObstruction.resolve()` para pequena correção do olho, mantendo o mesmo corpo.
- Testar `Camera3D.near` atual (~0,035) e clipe da arma real ao recarregar, correr, mirar e apontar para parede. **Não** aumentar FOV da arma por render separado enquanto o cano real fica em outra posição; preferir ajustar pose/colocação única e FOV de câmera testado.
- FPP não pode espiar por fissura/quina onde a cápsula/linha validada do corpo não permitiria tiro. O shot-camera envelope de `WarPlayer.shot_camera_valid()` e a raycast câmera->cano/mundo continuam obrigatórios.
- A câmera terceira pessoa permanece no `SpringArm3D` da Guerra, com collision sweep, transição contínua e enquadramento lateral. Quando o braço retrair junto a uma parede (`camera_close`), a passagem para FPP NÃO recria modelo nem reseta recarga.
- **Optical PiP:** `scripts/weapon_optics.gd` tem `PRESENTATION_LAYER=1<<18`, `_view_scope` orientado à cópia e `SubViewport`. Migrar o acesso para o escopo da arma real, excluir do viewport a própria lente/superfície que renderiza o viewport, evitar recursão, ajustar máscara de mundo e preservar 4x/8x. Verificar render layers usadas por outros sistemas ANTES de reservar outra camada.
- Oculte apenas a malha de cabeça quando preciso. Não fazer `avatar_parts.arm_l.visible=false` na FPP; isso é o bug arquitetural que se deseja eliminar.

**Decisão importante:** `single-weapon + one-pose + true full-body` é ideal; **um proxy FPP temporário** é aceitável só se derivar rigidamente das transforms finais reais e não tiver lógica/tempo/autoria própria. No fim o alvo é removê-lo.

## 6. Armas e empunhadura: migrar sem quebrar

### Primeiro G3
- Fazer auditoria de nós `G3Model`, `GripRight`, `SupportGrip`, `Magazine`, `ChargingHandle`, `RearIron`, ótica, retículo e `Muzzle`. Verificar que cada um existe e tem transform consistente após troca de equipamento.
- Parar de duplicar a arma ao entrar em FPP. Mão direita e esquerda resolvidas uma vez, com o `WarHumanRig.pose()` original. Quando o G3 entrar em recarga, aplicar `GameReloadPose.state()` **uma vez** ao modelo real; mãos seguem os mesmos marcadores animados.
- Corrigir o posicionamento de arma no ombro olhando para baixo, deitado e ao lean. Se a anatomia ficar ruim na FPP, melhorar o rig/câmera/offset único, **não mover apenas uma cópia**.
- Trazer calço da coronha, ADS e recuo como componentes de pose e eventos, não como uma segunda árvore de arma; o muzzle responde ao mesmo resultado.
- Testar Glock, FAL e AK depois do G3; sniper com bolt e óptica depois. **Granada, melee, fists BR, RPG/Javelin, binóculos e medic** exigem adapters próprios baseados em PoseState único.
- Não trocar alcance, munição, dano ou tempo de reload: o passo é **consistência de apresentação**.

### Transição de recarga
`NORMAL -> RELOAD_START -> MAG_OUT -> MAG_IN -> CHAMBER -> READY`, sendo os intervalos **marcadores visuais** sobre `reload_left/reload_total` do servidor. Modelos externos observam o mesmo `progress`. Se interromper equip, morte, veículo, tiro aceito ou fase da partida, o estado visual deve ser resolvido uma vez, sem soltar uma munição a mais ou duplicar carregadores.

## 7. Compatibilidade com rig procedural, esquelético, IK, hitboxes e ragdoll

**Plano A obrigatório:** primeiro remover a divergência com o sistema procedural já funcional. `WarHumanRig.pose`/pivôs atuais são a fonte de pose para as duas câmeras. Isso entrega a melhoria sem precisar de uma reforma de esqueleto.

**Plano B posterior:** soldado protótipo isolado com `Skeleton3D`, `AnimationTree` e `SkeletonModifier3D`. O `AnimationTree` aplica caminhada, corrida, crouch, prone e transições; só depois modificadores/IK posicionam mãos no mesmo modelo de arma. O Godot 4.7 garante que os modificadores executem depois do `AnimationMixer` e o ordem é por filhos, útil para garantir IK de braço após torso. Não usar modificador para mover câmera nem autoridade de tiro.

**Durante migração esquelética:** construir um adapter (`RigHitRegionAdapter`) que atualiza `Area3D` por membro no mesmo ponto físico usado hoje. A cabeça não pode se tornar 'imortal' por deixar de ser desenhada; a versão remota recebe as mesmas áreas físicas. `DeathRagdoll.create()` assume peças e nomes (`ArmLMesh`, `ForearmLMesh`, `ShinL` etc): precisa de adapter que extrai pose final, malhas, pesos, roupa, equipamentos e vínculos do esqueleto sem transformar o ragdoll em uma nova arma.

**Sem root motion gameplay neste pacote:** a cápsula `CharacterBody3D` permanece autoritativa; animação acompanha deslocamento já autorizado. Uma migração para root motion exigiria rever rede/colisão e fica fora desta iniciativa.

## 8. Matriz de riscos obrigatória

| Contexto | Problema provável | Solução/critério |
|---|---|---|
| FPP em ADS + alternar TPP | arma desloca e munição 'salta' | mesma arma/estado; zero restart de reload |
| Câmera em parede/encosta | interior do rosto ou do colete, tiro atravessa quina | camada local de cabeça + solver + raycast |
| Câmera TPP retract `camera_close` | instanciar/destruir cópia e perder pose | só trocar máscara/enquadramento |
| Escopo PiP, 4x/8x | lente recursiva ou zoom falso | ótica real, camada protegida, medir magnificação no alvo |
| Deitado mirando baixo | cano elevado acima da câmera ou mãos esticadas | pose única + teste de muzzle e pegadas |
| Troca de arma durante recarga | duplicação carregador / dois estados | timer autoritativo, adapter de ação idempotente |
| Armas de fogo comuns | variações de grip/attachments | nomear sockets e validar poses para cada arma |
| Granadas/arremesso | objeto sai de mão diferente na FPP/TPP | mesmo `release_transform` validado |
| Socos BR | mãos de FPP atingem visualmente alvo diferente | evento `punch` único, alcance de gameplay preservado |
| Melee/rodo/machado | acerto visual sem sweep físico | sweep segue rig real, não câmera |
| Binóculos/medic | modelos cortam rosto ou duplicam mão | adaptadores com mesma ação e sockets |
| RPG/Javelin | FPP duplica lançador e olhos não alinham | um launcher real, estado e alcance server |
| Entrar/sair veículo/drone | mãos ficam presas na pose antiga | reset atômico do pose state, sem reconstrução da arma por câmera |
| Morte e ragdoll | avatar oculto/pose errada no corpo | snapshot final antes do ragdoll, adapter |
| Bots 28/57, grande distância | excesso de solve e GPU skinning | render/pose LOD, preservar física e IA |
| BR versus Guerra | sincronização/protocolos diferentes | suites separadas e protocolo versionado se mudar |
| Replays/câmera espectador | visão muda arma do jogador observado | só observador escolhe câmera; actor nunca tem pose por observador |

## 9. Cronograma de execução e feature gates

| Fase | Modificação | Gate para avançar |
|---|---|---|
| **P0a/P0b — baseline** | P0a iniciada: testes headless e fixture G3 em 1.13.1; P0b pendente: capturas FPP/TPP, cobertura, rede real, 28 bots, profiling | só concluir quando a matriz for reproduzível; ver revisão v2 |
| **P1 — contrato de física/mira** | Criar `PoseState`, `CollisionPose` (hitboxes em tick físico) e `PresentationPose` (LOD visual); definir `LogicalAimOrigin` comum sob flag, mantendo balística anterior no piloto | hitboxes independentes da câmera/distância + teste do disparo ACEITO em quinas/janelas |
| **P2a + P3a — G3 sem óptica e câmera real** | Primeiro instalar culling local da cabeça, corpo/mãos/cano reais e câmera FPP/TPP; manter `view_root` como fallback nas demais armas/ópticas | G3 com mira de ferro correto em FPP/TPP, sem sumiço ou clipping |
| **P2b + P4 — óptica G3** | Migrar PiP para lente da arma REAL antes de apagar cópia; 4×/8× e SubViewport renderizado | sem recursão, sem zoom falso e sem regressão balística |
| **P2c — desligar cópia G3** | Após G3 irons/ópticas, remover `view_root` **somente do G3** sob flag | 20 alternâncias FPP/TPP em recarga e ADS; zero reconstrução de arma |
| P5 — arsenal | AK, FAL, Glock, sniper; recarga, equip, acessórios, disparo | cada arma segura em FPP/TPP/remote, sem duplicar material |
| P6 — especiais | Granadas, socos BR, melee, RPG/Javelin, médico, binóculos, prone, ragdoll, veículos | matrizes offline/BR/Guerra completas |
| P7 — rig futuro | Piloto esquelético opcional, animation retarget/IK, hit region adapter | só substituir rig padrão se qualidade e custo aprovados |
| P8 — otimização/release | testes fim-a-fim 28 bots, 40 BR, rede, headless e builds | estabilidade, visibilidade, hitbox, FPS, nav; somente após aprovação |

**Ordem corrigida v2:** P0 (baseline) → P1 (mira lógica especificada e hitboxes desacopladas do LOD visual) → P2a+P3a (G3 sem óptica + câmera/culling real) → P2b+P4 (PiP na óptica real) → P2c (retirar FPP copy G3) → demais armas → BR/especiais → soldado esquelético. Ver [revisão P0](FPP-TPP-REVISAO-P0-20261104.md). Não começar tudo pelo `Skeleton3D`.

## 10. Testes automatizados propostos (novos fixtures, NÃO CRIADOS AINDA)

- `tests/true_fpp_pose_consistency.gd`: a mesma pose de G3/AK/FAL/Glock/Sniper resulta em **exatamente um** `HeldWeapon` de gameplay e nenhuma mão duplicada.
- `tests/true_fpp_grip_alignment.gd`: erro de mão até o grip **≤ 2 cm** parado, **≤ 3 cm** caminhando, **≤ 4 cm** somente durante transições de recarga; medir deformação e cotovelo sem atravessar o corpo. Metas iniciais ajustáveis após linha-base.
- `tests/true_fpp_muzzle_alignment.gd`: alternar câmera 20x durante ADS/fogo e comparar transform do `muzzle_marker` antes/depois da alternância **≤ 1 mm e 0,1°** em estado igual, sem alterar dano nem alcance. Testar raycast de parede perto.
- `tests/true_fpp_reload_timeline.gd`: 10 alternâncias FPP/TPP por recarga, interrupções, troca, reentrada, morte; zero recomeço ou alteração em ammo; um som por evento.
- `tests/true_fpp_camera_clipping.gd`: paredes, pequenas portas, colunas, janelas, calhas, escadas, trincheiras, pose prone/lean, SpringArm3D, câmera que retrai para FPP; nenhuma visão de malha interna/peek indevido.
- `tests/true_fpp_optical_parity.gd`: manter testes atuais `optical_magnification_measured_20261104.gd`, `br_optic_duel.gd`, `scoped_muzzle_regression.gd`, mais varredura 4x/8x com posição fixada e sem lente recursiva.
- `tests/true_fpp_actor_replay.gd`: dois clientes com jitter/perda artificial, screenshot da pose local FPP, TPP e remoto no mesmo instante lógico e só um disparo validado/seq.
- `tests/true_fpp_ragdoll.gd`: kill em head/chest/arm/leg durante reload, prone/lean e troca de arma; sem hit region sem dono e sem corpo desmembrado incorretamente.
- `tests/true_fpp_loadout_modes.gd`: offline, BR, Guerra, veículos, moto, drone, espectador, medic, launcher, socos e granadas, incluindo 40 participantes BR e 28 bots Guerra.
- `tests/true_fpp_performance.gd`: A/B no mesmo PC, 1080p/28 bots, mediana e p95/p99, draw calls, objetos renderizados, consumo GPU, memória e largura de banda de snapshots. Não prometer 60 FPS enquanto versão-base não atinge isso.

**Regressões existentes indispensáveis:** `tests/pose189_validation.gd`, `tests/pose189_network.gd`, `tests/war_locomotion.gd`, `tests/war_locomotion_network.gd`, `tests/prone_weapon_pose_validation.gd`, `tests/scoped_muzzle_regression.gd`, `tests/br_optic_duel.gd`, `tests/reload_resume_network.gd`, `tests/camera_collision.gd`, `tests/war163_player_camera_respawn.gd`, `tests/war166_camera_probe.gd`, `tests/war_multiplayer.gd`, `tests/br_motorbike_camera_fixture.gd`, `tests/optics_universal_validation_20261103.gd`, `tests/optical_magnification_measured_20261104.gd`.

## 11. Critérios de aceite de desempenho e de release

- **0 cópias do HeldWeapon como entidade de gameplay** e 0 recargas com avanço de relógio por perspectiva.
- Sem mudança de hit detection, munição, postura validada ou dano; colisores do corpo permanecem no mesmo lugar após trocar apenas câmera.
- O jogador remoto vê pose, recarga, punhos e arma correspondentes ao mesmo estado lógico do local. Interpolação legítima da rede pode causar pequena diferença transitória **mensurada**, nunca arma diferente ou animação divergente.
- 20 alternâncias de câmera durante ação não causam instância nova, salto de estados, disparo extra, popup de escopo, perda de listeners nem RIDs órfãos.
- Sem regressão importante de FPS, média, p95/p99 em perfis Compatibility Baixo/Médio no i5-11400H/GTX 1650 com 28 bots. Como primeira regra de validação, exigir **mediana não pior e p99 sem acréscimo > 5% fora do ruído**; pode impor limites mais rígidos após medição pareada.
- Sem aumentar RPC por quadro e sem autorizar o cliente a determinar cano/hitboxes. Mudança de protocolo só se não houver como reaproveitar snapshots existentes, com compatibilidade de builds versionadas.
- Manter flags de comparação, por exemplo `--true-fpp-pilot`, e opção de rollback por ator/arma; não deletar o sistema anterior até todos os modos passarem.
- A navegação preparada do Afegão está desatualizada independentemente desta tarefa. Unificação do personagem não deve regenerar mapas nem tocar em spawns/loot; o release final do Afegão ainda depende do pipeline e da certificação de 28 bots.

## 12. Arquivos esperados da implementação (sugestão de arquitetura)

```text
scripts/character_pose_state.gd             # estado lógico + tempos
scripts/character_pose_controller.gd        # ordenação de pose por tick
scripts/character_weapon_rig.gd             # arma e grips únicos
scripts/character_camera_controller.gd      # FPP/TPP/SpringArm
scripts/character_view_visibility.gd        # masks locais/cabeça
scripts/character_pose_debug.gd             # overlays/erros de grip
modes/war/scripts/player.gd                # adapter Guerra, sem duplicação
modes/battle_royale/scripts/player.gd      # adapter BR, fists
scripts/player.gd                          # migração progressiva
scripts/weapon_optics.gd                   # lente PiP montada no mundo
scripts/reload_pose.gd                     # produtor de pose única
scripts/death_ragdoll.gd                   # compatibilidade com rig futuro
tests/true_fpp_*.gd                        # testes por contrato
```

Nomes são **propostos** e não exigem reestruturação total. Não gerar módulos redundantes sem justificativa; se puder aproveitar `WarHumanRig`, `GameInfantryPose` e `GameReloadPose`, fazê-lo.

## 13. Referências técnicas verificadas

- Godot 4.7 Camera3D / cull_mask: https://docs.godotengine.org/en/4.7/classes/class_camera3d.html
- Godot VisualInstance3D / layers: https://docs.godotengine.org/en/latest/classes/class_visualinstance3d.html
- Godot 4.7 SkeletonModifier3D: https://docs.godotengine.org/en/4.7/classes/class_skeletonmodifier3d.html
- Godot AnimationTree: https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html
- Godot performance 3D (skin/LOD): https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html
- Godot 4.7 High-level multiplayer / server authority: https://docs.godotengine.org/en/4.7/tutorials/networking/high_level_multiplayer.html
- Godot skeleton retargeting (futura fase): https://docs.godotengine.org/en/latest/tutorials/assets_pipeline/retargeting_3d_skeletons.html

## 14. Ponto de partida aprovado para implementação futura

**P0+P1 no projeto local**, captura e estrutura de PoseFrame; **P2 para G3 apenas**, sem alterar visual de BR/War até teste real do dono/observador. A partir daí liberar por arma. O objetivo é uma só lógica, não deixar a câmera governar a física.

**Esta entrega é APENAS documentação de plano.** Nenhuma função do jogo foi modificada, nenhuma cena `view_root` removida, nenhum pacote publicado.
