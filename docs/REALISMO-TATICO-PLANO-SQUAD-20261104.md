# Plano diretor — realismo tático estilo Squad (movimentos, animações, armas e gráficos)

**Emissão:** 04/11/2026  
**Projeto auditado:** Toque de Campo, versão local `1.13.1` declarada por `project.godot`, Godot 4.7 / Compatibility; plano, **nenhuma mudança de runtime, cena, rede ou versão por esta entrega**.  
**Referência interna obrigatória:** `docs/AFEGANISTAO-REFERENCIA-SINAI-TRILHAS-20261104.md` (trilha de encosta, transição seca/verde, trilhas de flanco, proteção BR).  
**Princípio:** inspiração de intensidade, coerência de materiais e ritmo de combate do Squad, sem reproduzir modelos, sons, animações, interface, nomes comerciais de conteúdo, identidade visual ou assets protegidos.

**Protótipo P1b iniciado (04/11/2026):** [CollisionRigProxy independente em estrutura](FPP-TPP-P1B-COLLISION-RIG-PROXY-20261104.md), com 16 regiões físicas isoladas, shape próprio e cano virtual; paridade 0 m nas três posturas, testes aprovados. Não há solver físico independente nem ganho de FPS comprovado: próximo passo é portar matemática das articulações sem atualizar o visual.

**Continuação P1a (04/11/2026):** [A/B e rollback](FPP-TPP-P1A-COLLISION-LITE-EXPERIMENT-20261104.md). Lite e gatilho por eventos foram medidos e rejeitados pelo custo; gameplay restaurado byte a byte. Foi adicionado contrato de captura de CollisionPose e teste aprovado para FPP/TPP e três posturas. **Próximo gate: solver físico autônomo**, independente da malha visual e óptica, antes de mudar câmera ou arma.

**Evolução P1a (04/11/2026):** [piloto de colisão de personagem](FPP-TPP-P1A-PILOTO-20261104.md) criado em `WarPlayer` sob `--true-fpp-p1a-authority`, sem alterar o padrão do jogo. Host passou QA de 13 hitboxes/5 distâncias, mas o custo de pose completa com 28 atores passou de 3,39 ms para 7,53 ms em média. Para manter a GTX 1650 viável, **não ativar por padrão**; separar solver físico leve da apresentação antes da migração da câmera.

**Evidência complementar P0b (04/11/2026):** [FPP-TPP-P0B-RESULTADOS-20261104.md](FPP-TPP-P0B-RESULTADOS-20261104.md). G3 testado em seis casos de cobertura, quatro capturas gráficas na GTX 1650 e LOD de hitbox 10–1700 m; quina/janela revelaram diferenças FPP/TPP e há risco de hitbox desatualizada quando a pose visual é omitida. **P1a começa pela pose física em tick fixo, não pela troca das câmeras.** Rede real/28 bots e impactos balísticos finais pendentes. Essa anotação não altera o jogo.

**Atualização obrigatória 04/11/2026 — personagem único antes das demais animações:** o [plano FPP/TPP](FPP-TPP-CORPO-UNICO-PLANO-20261104.md) e sua [revisão técnica P0 v2](FPP-TPP-REVISAO-P0-20261104.md) passam a ser o pré-requisito de arquitetura. A `view_root` duplica arma/mãos; retirar gradualmente. Atenção: mesmo cano físico NÃO garante hit idêntico porque hoje o alvo deriva da câmera TPP/FPP; definir mira lógica comum com validação anti-cheat, separando hitbox em tick fixo do LOD visual. **Ordem correta:** baseline P0 → contrato P1 → câmera/corpo real G3 sem óptica P2a+P3a → PiP na lente do mundo P2b+P4 → remover cópia G3 P2c → restante. P0 foi iniciada com testes headless: `scoped_muzzle_regression` falhou (326/490), `optics_universal` e `prone_weapon_pose` passaram, e novo fixture G3 confirmou cópia visual desalinhada e manete parado. Não corrigir à força com offsets nem mexer na física sem gates. Nenhuma mudança de gameplay nesta revisão.

## 0. Diagnóstico do projeto REAL

- `scripts/player.gd`: `GamePlayer extends CharacterBody3D`, com `avatar_parts` do corpo construídas por código, region hitboxes, `weapon_root`, `view_root`, recoil, aiming e snapshot de rede. Não é hoje um avatar `Skeleton3D + AnimationTree` uniforme.
- `modes/war/scripts/human_rig.gd`: braços/mãos articulados com solução de cotovelo por matemática; arma física determina as posições das mãos. Afetar rig implica checar hitboxes, recargas, primeira/terceira pessoa, ragdoll, uniformes e rede.
- `modes/war/scripts/locomotion.gd`: marcha baseada no deslocamento real, phase senoidal para pernas, torção de tronco, bob do armamento e sons de passos; já há coerência física básica, mas falta leitura de transferência de peso/impacto e riqueza de transição.
- `modes/war/scripts/stance.gd`: agachar e deitar mudam a cápsula física, têm teste de desobstrução e pose visual; não substituir por efeitos apenas cosméticos.
- `scripts/infantry_pose.gd`: inclinação lateral com sweep contra paredes, pitch/lean no tronco/câmera e acoplamento arma-mãos; conservar a correção do cano e da vista ao mirar.
- `scripts/reload_pose.gd`: recargas AK, FAL/G3, Glock e sniper são interpoladas a partir do temporizador autoritativo; nem todas têm movimentos de magazine e ferrolho realmente separados.
- `scripts/weapons.gd`, `scripts/combat_rules.gd`, `scripts/bullet_physics.gd`: parâmetros por arma, projéteis com gravidade e arrasto, recuo e dispersão. Não substituir balística determinística com raycast cosmético.
- `modes/war/scripts/soundscape.gd`: passos por superfície, vozes 3D e oclusão acústica; já há trabalho de som em outro fluxo. Integrar eventos de animação ao áudio existente, sem reescrever o mixer paralelamente.
- `modes/war/scripts/player.gd`: operações com binóculos, RPG, prone, lean, câmeras FPP/TPP. `modes/battle_royale/scripts/player.gd` herda sistemas comuns.
- `modes/battle_royale/map/afghan_landform.gd`: mapa 2 × 2 km, montanhas, vielas, vias de subida, riacho, cultivos; mudanças v11/v12/v13 locais; `docs/AFEGANISTAO-REFERENCIA-SINAI-TRILHAS-20261104.md` prevê fase v14.
- Limite de referência de desempenho: notebook i5-11400H + GTX 1650 / 1080p e 28 bots. Em `work/performance-pilot-20261103/RELATORIO.md`, mediana Compatibility A/C 22,12–24,87 FPS; Forward+ 61–62 FPS medianos com p99 >160 ms e média substancialmente pior. **Não considerar 60 FPS atingidos**. Revisar benchmark atual antes de decidir implementação.
- Os recursos de navegação preparados do Afegão estão desatualizados diante da geometria local. Regerar pelo pipeline oficial BR -> mapas -> Guerra antes do release. Nunca falsificar hash.

## 1. Direção de experiência: o que imitar e o que NÃO imitar

**Alvo:** mover-se com peso, ter postura legível, reagir a terreno, olhar e portar arma como um soldado, identificar arma pelo som/silhueta/cadência, sentir distância, poeira e choque dos disparos, e escolher trilha, muro ou baixada como proteção. O resultado precisa continuar responsivo, compreensível e competitivo.

**Evitar:** bob que dá enjoo, sway imprevisível que atrapalha mirar, blur constante, supressão que desliga a mira do jogador, recargas longas sem justificativa, física pesada em cada objeto, fumaça volumétrica sem orçamento, fotorealismo inconsistente com personagens low-poly, e componentes exclusivos de jogo específico.

**Aprendizado de Squad:** as próprias revisões de 2025–2026 reequilibraram ADS, recoil, sway, stamina, suppression e efeitos de projéteis, com prioridade para previsibilidade/feedback e desempenho. Clonar a curva mais punitiva de uma edição específica não é objetivo.

## 2. Fase zero — contratos e medições (antes de alterar controles)

1. Congelar referência visual e física com cinco capturas do Afegão, cinco da Ucrânia e gravação curta da FPP e TPP com G3 e AK: parado, andando, correndo, agachando, deitado, descendo rampa e recarregando.
2. Medir no teste e jogo real: frame p50/p95/p99; CPU/GPU/física; draw calls; memórias; tempo de carregamento; latência de envio/recebimento; fidelidade de tiros após troca de postura; visibilidade de inimigos a 50/200/600/1700 m.
3. Registrar matriz de compatibilidade: Offline / BR / Guerra, humano / bot, FPP / TPP, veículo, classes, óticas e perfis gráfico baixo/médio/alto.
4. Separar `motion gameplay` autoritativo de `motion presentation` interpolado. Hitboxes e cano real nunca se atrasam ou mudam de lugar só porque uma animação está suave.
5. Para experimentos, usar novo módulo com flag `--tactical-motion-pilot` ou uma configuração interna QA; não tocar no padrão até comparação e rollback testados.

## 3. Fase um — animação e peso de movimento (prioridade máxima)

### 3.1 Melhorar já o rig procedural, sem trocar colisão
- **Pés:** cadência assimétrica de caminhada/avanço diagonal, transição de impacto de calcanhar e ponta, posição vertical baseada no ponto real do solo, passo curto em descidas e inclinações; a câmera não deve oscilar junto do hitbox.
- **Quadril e tronco:** rotação de pelvis, deslocamento lateral do centro de massa, antecipação de curvas e atraso suave da mochila/peitoral; evitar deslizamento dos pés.
- **Frear, arrancar, virar:** aceleração visual nos primeiros 0,1–0,25 s, desaceleração, giro de corpo quando direção e olhar divergem; não adicionar inércia fictícia à lógica de rede sem aprovação.
- **Marchas:** parado, caminhada, corrida, sprint, deslocamento lateral, ré, postura abaixada, rastejo, salto e aterrissagem, queda/escorregamento em declive.
- **Posturas:** transições suavizadas de standing ↔ crouch ↔ prone; verificar colisão antes de levantar. Tiro e recarga interrompem/transitam de maneira coerente; sem teleportar mãos.
- **Interações:** entrar/sair de veículos, pegar loot, curar, tirar binóculos, preparar granada, tirar arma das costas. Eventos somente após aceite do estado do servidor.
- **Animação FPP e TPP:** preservar mesma arma/tempo/estado; permitir poses de apresentação separadas para o dono e observadores, mas cano e disparo obedecem à mesma origem física validada.

### 3.2 Migração progressiva para rig esquelético — decisão após piloto
- Criar **um soldado de teste** em `res://modes/war/library/` com `Skeleton3D` padrão humanoide e clips importados/autorais, retargeting revisado e `AnimationTree` com `BlendSpace2D` (locomoção), state machine (ações), blends da parte superior e grip IK.
- Manter `CharacterBody3D`, `stance.apply_collision`, regiões de hit independentes, ragdoll e rede; primeiro comparar visual esquelético a rig atual como skin alternativa. Nenhum refactor direto do `GamePlayer` até equivalência.
- Comparar custo CPU/GPU com 28 bots. Para bots distantes usar animação simplificada, atualização em frequência reduzida e LOD de corpo, **sem desacelerar física, IA ou hit detection**.
- Se resultado superar o procedural com qualidade/custo aceitáveis, migrar avatar e uniformes por fases: Guerreiro G3 -> soldado AK/FAL -> classes -> BR -> NPC -> outros modos. Se não, conservar sistema híbrido.

## 4. Fase dois — manuseio realista de armas (G3 como piloto)

1. **Idle/equip:** posição de prontidão baixa, prontidão alta, alinhamento ótico e entrada/saída do ADS em tempo previsível; inclinação natural do rifle na corrida.
2. **Recoil:** primeira subida de boca, impulso recuperável, variação por arma e cadência, microdeslocamento do ombro e retorno controlado. O recuo visual não pode mover projéteis sem coincidência entre cano da autoridade, predição local e replicação.
3. **Sway e fôlego:** sway de baixa amplitude dependente de movimento, postura, carga e esforço; variação suave, sem ruído aleatório frame a frame. Breath hold com custo limitado, sobretudo após sprint. A mira continua utilizável.
4. **Supressão:** classes de armas distintas (G3/FAL x AK x sniper x metralhadora), curva curta de acúmulo/decadência e efeitos leves de saturação sonora/visual e sway. Só near misses de projéteis autoritativos geram supressão; não dar dano adicional nem stun invisível. Desabilitar/desconectar filtro global se não houver validação de conforto.
5. **Recarga por fases:** pegar carregador, remover, inserir, confirmar e atuar mecanismo; som/objeto alinhado ao evento e estados autorizados; cancelar/retomar conforme regras existentes, sem duplicar munição. Primeiramente G3, depois FAL/AK/Glock/sniper.
6. **Apoio de arma:** resting contra muro, janela, saco e beiral; reduzir sway/recoil quando contato físico válido, checar colisão ao abaixar cano e possibilidade de mover o corpo. Bipé apenas após essa base e com animação/colisão consistentes.
7. **Ópticas:** medir ampliação óptica real dentro da lente, não só cadastro de valor, com 4x/8x no mesmo alvo e posição. PiP quando habilitado deve ter opção de escala/qualidade e fallback sem PiP na GTX 1650.
8. **Identidade de cada arma:** peso, alcance físico de alça/coronha, foco, tempo de ADS, tremor e recarga próprios. Não alterar dano/cadência de forma transversal sem comparação BR x Guerra; tabela central de parâmetros/presets.
9. **Balística:** conservar `GameBulletPhysics.advance()` (gravidade + arrasto), speed, spread e hit authority atuais. Melhorias opcionais são vento leve, dispersão de sustentação e ricochetes físico/materiais, somente se autoria e rede puderem representar com precisão.

## 5. Fase três — visual mais realista sem abandonar a identidade

- **Personagem:** proporção humana padronizada, silhueta militar verossímil, joelhos/cotovelos naturais, placas/cintos/luvas/botas/mochila, modelos com textura de tecido/borracha/metal com roughness variável; cores mais dessaturadas e consistentes. Não voltar à configuração de proporções exageradas.
- **Armas:** malhas próprias detalhadas e consistentes, coronha, trilhos, carregador, gatilho, seletor, ferrolho, óticas, detalhes mecânicos visíveis na FPP; versões LOD para TPP a longa distância; autorias/licenças registradas.
- **Terreno (documento do Sinai, v14):** solo do Afegão com pedras pequenas e cascalho não colidentes, trilhas que acompanham contornos, zonas de erosão, sedimentos ao pé de encostas, transição de solo cinza/ocre, vegetação concentrada no vale; não reativar grandes rochedos removidos a pedido do usuário.
- **Cenário construído:** parede de adobe com variações, reboco irregular, bordas danificadas, janelas profundas, portas, sombras de entrada, pátios agrícolas e estruturas reutilizáveis. Preservar os 375 loot anchors originais + 12 v13, entradas, spawns, rotas e locais de veículos.
- **Luz/atmosfera:** céu coerente, direção do sol, contraste sem esmagar sombras, neblina atmosférica escalonada e haze distante barato. Evitar volumetric fog/GI dinâmica no perfil 1650 sem aprovação.
- **VFX:** muzzle flash breve, fumaça residual variável, poeira do solo por material, cascas, faíscas, traçantes fisicamente alinhados, estilhaços com pooling, nuvem/ondas de choque em explosões pesadas. Limitar partículas por distância e orçamento de pico.
- **Interface:** feedback de tiro/reload/postura/supressão mínimo, leitura rápida de munição e status; animações de menu e transição leves, sem copiar HUD de Squad.
- **Densidade de detalhes:** cada objeto novo vira peça em biblioteca e catálogo. Colisões idênticas em cliente/autoridade. Objetos visuais em MultiMesh, culling, LOD/HLOD por distância, textura/material compartilhados; sem scripts individuais.
- **Perfil de gráficos:** Baixo para estabilidade, Médio compatível com GTX 1650, Alto opcional para hardware forte. Não reduzir visibilidade de inimigos/hitboxes por preset. Distância visual de coberturas físicas igual ou superior à distância em que podem bloquear tiro.

## 6. Fase quatro — som, percepção, IA e rede

**Som:** disparo G3 próprio já desenvolvido deve conservar assinatura de distância/proximidade; envelopes para tiros, ricochetes, supersonic crack, impacto por material, camadas de explosão, reverb suave de vale e atenuação/oclusão. Passos sincronizados com *contato de pé* (não timer arbitrário), tempo de recarga com eventos reais. Não sobrescrever o pacote de sons de tanque que outro chat está trabalhando sem conferir integração.

**IA:** bots precisam expressar os mesmos estados de postura, arma, recarga e supressão que humanos, sem cobrar custo de animação completa fora da vista. Evolução visual da IA não deve afetar lógica de navegação, ocupação de veículos, cobertura e objetivos. Os 28 bots online e potencial futuro de 57 são metas de carga, não autorizações para reduzir tick de gameplay.

**Rede:** servidor envia estado compacto (`gait`, `stance`, `ADS`, `reload_phase`, `fire_event`, `lean`, `life_id` e identificador de arma) com versionamento/quantização; clientes interpolam apresentação, não o tiro autoritativo. Evitar RPC para cada frame de animação. Usar estados já existentes quando possível e medir custo/banda antes de expandir payload.

**Ragdoll/dano:** conservar regiões de impacto e reação coerente; não fazer dano visual invisível quando rig/hitbox descolam. Ragdoll ativo só nas proximidades relevantes; corpo estático ou desativação controlada em distância, sem desaparecer antes da lógica de loot/espectador.

## 7. Fases executáveis e gates (não lançar tudo de uma vez)

| Ordem | Entrega | Demonstração verificável | Critério de avanço |
|---|---|---|---|
| 0 | Benchmark e cena QA | 28 bots + G3 em FPP/TPP, Guerra e BR; métricas de movimento/rede | Baseline reprodutível e rollback |
| 1 | Peso de locomoção procedural | Andar, correr, parar, virar, abaixar/deitar, slope | Zero clipping e hitboxes íntegras |
| 2 | G3 de referência | ADS, sway, recoil, recarga, eventos de som, ótica | Tiros coincidem com cano + rede, sem regressão |
| 3 | Piloto de `Skeleton3D` | Avatar paralelo, retarget e hand IK | Qualidade melhor sem custo excessivo |
| 4 | Materiais/cenário v14 | Uma trilha de 150–250 m, parede/solo/poeira, bioma | Rotas de BR/Guerra e FPS aprovados |
| 5 | Demais armas e classes | FAL, AK, Glock, sniper, lançadores, médico, anti-tanque | Todas as classes e controles |
| 6 | Atmosfera/VFX/som | Dia/noite, impacto, ricochete, explosão e distância | Mix sem clipping, efeitos escaláveis |
| 7 | Bots, online e exportação | humano/bot, 40 participantes BR, 28 bots Guerra, distância 1700m, entrar/sair veículos | Performance A/B, nav preparada válida, sem divergência de hits |

## 8. Regras de compatibilidade e rollback

- *Não alterar* sem teste específico: tipos de partida, objetivos, pontuação, IA, posicionamento de loot/spawn, distância efetiva de tiro, rotina de servidor, respawn, câmera de morte e saída de veículos.
- Preservar as cenas autorais, `map_additions.tscn` e as decisões de limpeza do relevo.
- Novas peças da v14 só entram quando 100% das colisões batem no cliente/servidor; navmesh oficial refeito e 40/40 spawns BR simulados, 375+12 loot, e rotas de moto/tanque livres.
- `AnimationTree` e retargeting: usar somente quando houver rig esquelético realmente importado; no sistema atual as fases 1–2 usam interpolação procedural e blend de poses. Nunca pressupor que portar código antigo será automático.
- Introduzir feature flags para piloto G3 e avatar/terreno e registrar capturas/benchmarks antes/depois. Rollback por camada, não por remoção de assets existentes.
- Testar FPS mediano, média, P95, P99 e stutters em 1080p com 28 bots. **Objetivo 60 FPS é uma meta**, não aprovação antecipada; nenhuma piora significativa na cauda do frame time sem decisão consciente.
- Repetir testes com internet real, duas máquinas, desconexão, armas rápidas, agachado/deitado, hitboxes por membro, 4x/8x, colisão de barranco, ragdoll e servidor headless. Só publicar depois de evidências do build final.

## 9. Primeiro pacote concreto recomendado

**Piloto 01 — “Corpo único FPP/TPP + G3 + Soldado + Encosta Afegã”**

**Pré-requisito obrigatório:** aplicar em piloto reversível as fases P0–P3 do [plano FPP/TPP](FPP-TPP-CORPO-UNICO-PLANO-20261104.md) antes de criar animações novas: uma pose de braços/corpo, uma arma real, uma recarga, uma origem de disparo e duas posições de câmera, sem duplicar estado. Só avançar a locomotion mais realista depois do teste de câmera/mãos/ópticas.

1. Criar fixture de movimento FPP/TPP: 1 soldado G3, um bot, rampas, muro, janela, caixa e superfície de terra/pedra, com medição de hitboxes.
2. Melhorar a resposta visual procedural à aceleração, freada, curva, marcha baixa e contato de pé, sem trocar a física.
3. Ajustar transição de arma à corrida/ADS, balanço, recoil recuperável e gestos de recarga do G3, mantendo as óticas realmente ampliadas na lente.
4. Em paralelo apenas como **cena isolada**, prototipar rig esquelético para avaliar se migração compensa. Não substituir o avatar em produção nesse pacote.
5. Criar render comparativo de encosta do documento Sinai (sem adicionar geometrias ainda) para orientar luz e materiais. Só autorizar obra física v14 após nav + benchmark.
6. Entregar clip FPP/TPP antes/depois, teste headless de tiro/cápsula, validação de alinhamento de mão-cano e tabela p50/p95/p99. Avançar para AK/FAL e outros modos se tudo passar.

### Referências técnicas e de direção consultadas

- Squad — Infantry Combat Overhaul e atualizações: https://store.steampowered.com/news/posts/?enddate=1695244007&feed=steam_community_announcements
- Squad — roteiro de ajustes de 2026: https://store.steampowered.com/news/posts/?appgroupname=Squad&appids=393380&enddate=1768849225&feed=steam_community_announcements
- Squad 10.4 (recuo/sway): https://steamdb.info/patchnotes/22936205/
- Squad 10.5.2 (supressão, áudio): https://store.steampowered.com/news/posts/?appgroupname=Squad&appids=393380&enddate=1787247470&feed=steam_community_announcements
- Godot AnimationTree: https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html
- Godot retarget de esqueleto: https://docs.godotengine.org/en/latest/tutorials/assets_pipeline/retargeting_3d_skeletons.html
- Godot otimização 3D: https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html
