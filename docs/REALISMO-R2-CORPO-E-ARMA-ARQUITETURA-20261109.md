# Realismo R2 — arquitetura de quadril, tronco e arma (execução em gates)

**Data:** 09/11/2026
**Branch de estudo/primeiro piloto:** `ia/realismo-r2a-pose-contract-20261109`
**Base Git:** R1C `0b8f86a`
**Projeto:** Toque de Campo / modo Guerra / Godot 4.7.2
**Estado:** R2A contratual + R2B FPP G3 isolada; R2C física/TPP **NÃO autorizada por padrão**.

## 1. Problema

R1A, R1B e R1C acrescentaram sensação de massa na cópia FPP (`view_root`): aceleração/freada, movimento lateral/curva, e aterrissagem. Esses efeitos estão limitados e não movimentam o cano real.

O próximo nível de naturalidade depende de **transferência de peso entre quadril, tronco, ombros e arma**. Porém, acrescentar ângulos diretamente aos nós atuais não é uma operação visual inofensiva.

### Observações no código real

- `GamePlayer._animate_walk()` zera `avatar_parts.torso.rotation`, compõe torso/lean, chama `GameInfantryPose.apply()`, depois finaliza pernas/postura e resolve arma/braços;
- `GameInfantryPose.apply()` modifica `Pelvis`, `Torso`, `Head` e ombros, e as áreas de dano descendem desses pivôs/malhas;
- `WarPlayer._animate_walk()` pode pular atualizações visuais remotas por distância. Sem uma pose física autônoma, o hitbox acompanha o LOD;
- `WarHumanRig.pose()` faz IK das mãos até a empunhadura da arma mundial;
- `WarPlayer._update_weapon_pose()` aplica altura de crouch/prone e chama `locomotion.pose_weapon()`;
- o servidor usa a arma/cano real e valida a linha de tiro. A ótica PiP ainda se relaciona com a cópia FPP.

**Conclusão:** escrever livremente em `avatar_parts.torso` ou `body_root/Pelvis` mudaria posições de regiões físicas e poderia criar discrepância entre servidor, observador e FPP. A otimização P1k de CollisionRig permanece bloqueada por custo de CPU, e não pode ser silenciosamente contornada para introduzir novas animações.

## 2. Arquitetura escolhida

```text
CharacterBody / estado autorizado (sem mudança R2)
   │
   ├─ WarLocomotion (já existe, relógio dos pesos R1A/B/C)
   │   ├─ longitudinal [-1..1]  [aceleração/freada real]
   │   ├─ lateral      [-1..1]  [strafe/curva real]
   │   └─ landing      [ 0..1]  [contato físico ar→chão]
   │
   ▼
WarTacticalBodyPose (R2A, funções PURAS, nenhum tick próprio)
   ├─ hip_offset()             [intenção do centro de massa]
   ├─ hip_angles()             [intenção de contrarrotação do quadril]
   ├─ torso_angles()           [intenção do tronco/peitoral]
   └─ fpp_weapon_angles()      [fração amortecida vista pelos ombros FPP]
   │
   ├─ adaptador FPP G3 (R2B) — habilitado somente por flag
   │    └─ view_root.rotation, depois da base R1; câmera/arma real intactas
   │
   └─ adaptador físico/TPP (R2C) — BLOQUEADO até gate P1
        ├─ resolver pose física autoritativa a 60 Hz sem custo proibitivo
        ├─ aplicação visual de quadril/torso no rig do mundo
        └─ regiões, ombros, IK, ragdoll e cano coerentes no mesmo frame
```

### Abstrações e responsabilidades

**Fonte dos sinais:** somente `WarLocomotion` mede deslocamento real. Não duplicar aceleração, cronômetro, filtro, phase ou eventos.

**Modelo puro:** `WarTacticalBodyPose` recebe três números normalizados e devolve vetores com saturação. Não recebe nós, não faz query, não tem relógio nem cache por ator; entradas iguais produzem saída igual.

**Consumidores:** cada adaptador tem direitos explícitos. FPP pode movimentar apenas a cópia visual temporária. O adaptador físico futuro deverá alimentar simultaneamente visual, colisões e empunhadura real, sem criar duas poses com relógios diferentes.

**Ordem:** estado/contato → pesos R1 → intenção R2 → pose física existente → IK/arma real → complemento FPP. Nenhuma mudança em tiro deve depender da transformação FPP.

## 3. Sinais, eixos e limites iniciais

Convenção: X = lado, Y = cima, Z = frente/costas locais; ângulos em radianos, deslocamentos em metros. Todos os sinais são limitados matematicamente antes do cálculo; NaN/Infinity viram neutro.

| Canal | Longitudinal | Lateral | Aterrissagem | Uso |
|---|---:|---:|---:|---|
| Quadril: posição X | 0 | 1,4 cm | 0 | transferência de peso lateral |
| Quadril: posição Y | 0 | 0 | até -1,2 cm | compressão de aterrissagem |
| Quadril: posição Z | -0,6 cm | 0 | 0 | contra movimento longitudinal |
| Quadril: pitch X | -0,012 rad | 0 | 0 | contrapeso |
| Quadril: yaw Y | 0 | +0,012 rad | 0 | direção do apoio |
| Quadril: roll Z | 0 | +0,016 rad | 0 | apoio lateral |
| Tronco: pitch X | +0,022 rad | 0 | +0,032 rad | flexão/pouso |
| Tronco: yaw Y | 0 | -0,010 rad | 0 | compensação da curva |
| Tronco: roll Z | 0 | -0,028 rad | 0 | compensação do quadril |
| G3 FPP: pitch X | +0,010 rad | 0 | +0,018 rad | resposta amortecida do ombro |
| G3 FPP: yaw Y | 0 | -0,007 rad | 0 | resposta lateral |
| G3 FPP: roll Z | 0 | -0,020 rad | 0 | peso da arma, sem giro excessivo |

Os valores da tabela são **amplitudes de intenção**, não valores aplicados aos pivôs reais do personagem. Na R2B somente a última tripla é usada, exclusivamente no `view_root`. O teto angular combinado da G3 é da ordem de 2° e não altera a orientação física do disparo.

### Por que não colocar outra mola?

R1 já possui tempo de entrada/saída para aceleração, lateral e pouso. Acrescentar outro filtro no corpo causaria atraso duplo e drift na mudança de direção. A R2 herda o mesmo instante e estado; a futura compensação visual por interpolação só pode acontecer depois de definir o PoseFrame autoritativo e verificar sua ordem.

## 4. Prioridades de ações e preservação de jogabilidade

| Estado | R2B G3 FPP | R2C corpo real futuro |
|---|---|---|
| Jogador vivo, implantado, a pé, em pé, sem ação | Pode apresentar peso | Depende de equivalência P1 |
| Aceleração/freada | Pequeno pitch | Quadril contrabalança tronco |
| Strafe/curva | Pequeno yaw/roll | Peso transferido sem mover cápsula |
| Queda no ar | Sem impulso de aterrissagem | Sem inventar contato |
| Contato ar→chão | Pitch curto sincronizado com R1C | Compressão física consistente |
| ADS/óptica | **Neutro:** preserva centragem | Rig único precisa garantir sight line |
| Tiro/recoil | **Neutro:** recoil tem precedência | Recoil comum autoritativo |
| Recarga | **Neutro:** mãos/grips têm precedência | Uma ação/relógio |
| Granada, gadget, melee, binóculo | **Neutro** | Adaptadores separados, sem herdar automaticamente |
| Agachado/deitado, natação | **Neutro no piloto** | Solução por postura e áreas de dano, gate próprio |
| Veículo, morte, respawn/teleporte | Reset/sem aplicação | Sem efeitos antigos persistentes |
| Bots e remotos | Nenhuma escrita R2B | Não ativar sem custo P1 aprovado |
| Alternância FPP/TPP | Só a FPP recebe complemento visual | Não reinicia ação nem altera hitbox |

### Invariantes que devem permanecer verificáveis

1. Nenhuma escrita R2B em `CharacterBody.velocity`, `body_collision`, `hit_regions`, `Pelvis`, `Torso`, `weapon_root`, `muzzle_marker`, `camera`, payload de rede ou bot.
2. Vida, postura, recarga, munição e origem balística continuam provenientes do estado atual.
3. O ângulo de disparo validado no servidor não muda ao ativar/desativar R2B.
4. A entrada em ADS neutraliza imediatamente a sobreposição R2B; saída recupera o comportamento sem soma acumulativa.
5. A arma visual recebe o complemento depois de seu transform base ser reconstruído, nunca repetidamente sobre o frame anterior.
6. Na fase R2C, nenhum hitbox pode usar a pose da câmera em vez da pose física do mesmo tick.
7. Impactos devem continuar vindo do contato físico, não de timer ou salto presumido.
8. Reproduzir A/B entre R1C e R2B sem modificar R1A/B/C.

## 5. Etapas — pequenas, com portas independentes

### R2A — contrato puro (implementável sem risco físico)

Criar `tactical_body_pose.gd` com alvos de quadril/tronco/arma, zero side effects e testes: neutralidade, simetria, sinais opostos, limites, NaN/Infinity, determinismo e custo. Nenhuma alteração em runtime físico.

**Gate:** testes completos; custo incremental baixo no lote sintético de 28 atores; zero nova query física ou estado replicado.

### R2B — G3 local FPP (reversível)

Ligar apenas `fpp_weapon_angles()` ao `WarLocomotion.pose_weapon()`, sobre o `view_root`, após R1A/B/C. Exigir as duas flags de QA:

```text
TDC_TACTICAL_MOTION_PILOT=1
TDC_TACTICAL_BODY_PILOT=1
```

Ou `--tactical-motion-pilot --tactical-body-pilot`. **Padrão desligado**. G3, em pé, sem ADS, sem disparo, recarga ou utility. Não replicar. A mesma função admite um futuro adaptador de corpo, mas ela não pode ser usada diretamente em nós com hitboxes por enquanto.

**Gate:** captura real Forward+ / GTX 1650, G3 neutro/aceleração/strafe/pouso; teste automático de câmera, cano, arma real, ADS, FPP e TPP. Regressões R1A/B/C e ópticas. Se falhar, desativar flag e isolar o erro.

### R2C — quadril/tronco visual do mundo + colisão (dependente de P1)

Não copiar `Pelvis`/`Torso` nem aplicar animação local unilateral. Antes:

1. Resolver P1k: 16 regiões físicas, 60 Hz no servidor, zero fallback defasado, custo A/B estável e aceitável; há regressão de CPU documentada na P1k.
2. Definir *PoseFrame* físico único e ordem explícita: stance, torso, head, arma mundial, grip IK, áreas e cano.
3. Portar `hip_offset/hip_angles/torso_angles` para um adaptador com transformação de mundo coerente e correção de IK, sem herdar delta visual acumulativo.
4. Validar 28 bots / 0–1700 m / humano local e remoto / 16 áreas / head/chest/pelvis, transição standing/crouch/prone, lean, sprint e pouso.
5. Testar pares ENet/DTLS, tiros próximos a paredes/coberturas, mortes, ragdoll, câmeras e distância de LOD. Nenhuma mudança de protocolo só para enviar ângulo cosmético.
6. Comparar GPU/CPU/frame p50, p95, p99 e uso de memória na GTX 1650 1080p.

**Gate de promoção:** não basta ficar bonito. A transformação corporal precisa ser correta para danos e servidor e não exceder o orçamento CPU. Qualquer desvio mantém a R2C fora da `main`.

### R2D — outros equipamentos e modos

Depois de R2C, calibrar FAL/AK, Glock, sniper, lança-foguetes, granada, medicina, binóculos e melee; depois BR. Sem autorização para simplesmente ligar a G3 em todos os itens.

## 6. Diagnóstico de regressões e protocolo de benchmark

O teste histórico `tests/war_locomotion.gd` falhou **6/34 na própria R1B** e **7/34 na R1C** em uma rodada recente da mesma máquina: contagem de atores, entrada/timing e asserts antigos. Esses números são variáveis por fixture; não considerá-lo um gate novo determinístico até corrigir premissas. R2B não deve mascarar esse problema.

Usar as suites focadas R1A (8/8), R1B (13/13), R1C (16/16), impacto físico R1C (10/10), calibração G3 e ópticas (242/242). Criar testes de R2 com inputs controlados e estado de gameplay invariável.

Para custo, fazer A/A e A/B com **mesma versão, mapa, flags, janela de foco e cena**, 28 atores, pelo menos cinco pares, e registrar controles de ruído antes de atribuir variação ao novo código. O teste matemático puro não certifica FPS. Não rodar benchmarks simultâneos com outros serviços de QA na mesma CPU.

## 7. Coordenação e publicação

- Novo branch/worktree exclusivos, baseados em `0b8f86a`.
- Alterações cirúrgicas e testes isolados; nunca `push` direto na `main`.
- Revisão de diffs, reservas/hashes `ai_coord.py`, commits pequenos, publicação da branch no GitHub para PR.
- Nenhuma build pública ou `main` sem gates de integração.
- Se P1k continuar acima do orçamento, **é correto parar na R2B e manter a R2C como contrato/experimento isolado**; não reduzir cadência física de regiões nem deslocar hitboxes apenas para fechar um teste.

## 8. Critério de qualidade visual

A sensação desejada é de **massa conectada**, não de câmera tremendo. O quadril absorve e inicia mudança lateral, o tronco compensa e o ombro suaviza o movimento da arma. A câmera deve permanecer estável e a direção de tiro legível. Movimento constante deve ser neutro; aceleração e pouso produzem picos curtos, sem balanço infinito. Se uma camada não acrescenta legibilidade perceptível na GTX 1650, não vale o custo dela.
