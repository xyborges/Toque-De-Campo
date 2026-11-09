# R2C: auditoria física e primeiro contrato de frame

09/11/2026. Branch local `ia/realismo-r2c-poseframe-20261109`, criada de
`f893572`. A última `origin/main` disponível no disco é `ce2653e`.
O fetch foi tentado, mas o sandbox recusou o acesso do Git Credential Manager
às credenciais. O usuário autorizou continuar com Git local. O conector
GitHub aparece instalado/habilitado, mas não expõe ferramentas nesta sessão.
Nenhuma dessas constatações confirma o estado remoto atual.

## Etapa A: referências e fluxo físico

A R2C original foi reproduzida antes de editar o runtime:
`tests/realismo_r2c_world_pilot.gd`: **105/105 PASS**, exit 0, Godot
4.7.2 `ed1daf0bf`, headless. O log local está em `work/r2c-baseline.log`.

Há uma distinção importante entre os nomes das branches:

| Referência local | Commit | Conteúdo auditado |
| --- | --- | --- |
| `origin/ia/realismo-r2c-world-20261109` | `f893572` | R2C-0 local/offline/TPP, OFF |
| `origin/ia/fpp-p1k-physical-replacement` | `2e0d5e2` | Base P1j de 04/11, anterior aos commits P1k |
| `origin/ia/fpp-p1k-retomada` | `f98c031` | P1k: solver/cache e compartilhamento visual/físico |

A auditoria usa os arquivos **commitados** dessas referências; não incorpora
as edições não commitadas de outras worktrees. A reserva P1k original ainda
consta ativa com alerta de hash. Não foi alterada nem encerrada.

### R2C e pivôs

`GamePlayer._animate_walk` aplica a pose-base, `GameInfantryPose.apply`,
`WarPlayer._finish_body_pose`, arma mundial e IK dos braços, nessa ordem.
`GameInfantryPose.apply` reescreve a posição do Pelvis e somente sua rotação Z;
a restauração completa guardada pela R2C é necessária para evitar drift X/Y.
O Torso é reconstruído pela locomoção antes da composição da R2C.

O adaptador R2C atua depois de locomoção/stance e antes de arma/IK. As regiões
de dano legadas descendem dos mesmos pivôs. O deslocamento deve conservar
essa relação; deslocar somente os Area3D seria fisicamente incorreto.
A arma e o cano verdadeiro são resolvidos pelo caminho existente.

### CollisionRig da retomada P1k

`WarCollisionPoseState.REGIONS` define 16 regiões em ordem estável. O proxy
duplica as formas na preparação, conserva offsets locais e transfere a
ativação das regiões legadas para as independentes. Apenas uma fonte fica
ativa; morte e veículos restauram as regiões legadas.

`WarCollisionPoseSolver.capture` captura o estado atual em um PoseInput
reutilizável; `solve_cached` usa Calibration e buffers por ator. Arma/óptica
reconstruídas invalidam o binding por identidade da instância. As poses
retornadas são buffers emprestados: devem ser consumidas antes do próximo solve.

Nos ticks visuais remotos suportados, `_p1g_pose_remote` calcula apresentação
e as 16 regiões juntas; `_p1g_collision_tick` consome o mesmo frame. Nos ticks
omitidos pelo LOD, calcula a pose física sem aplicá-la à malha. Ações não
suportadas refazem a pose legada atual antes de sincronizar as regiões.
Reduzir a frequência da apresentação não autoriza reduzir colisores a 60 Hz.

### Duplicações e custos a investigar

- O solver reproduz a matemática de torso, membros, arma e IK do caminho
  legado; manter duas fórmulas exige testes de equivalência contínuos.
- O fallback ainda precisa atualizar o rig visual para obter regiões atuais;
  evitar essa atualização sem implementar a ação no solver produziria stale.
- O caminho legado sincroniza 16 transforms globais, enquanto o caminho packed
  reutiliza transforms locais; árvores/IK e propagação de transforms continuam
  custo real mesmo quando alocações de dicionários são reduzidas.
- `GameInfantryPose.weapon_pose` recalcula upper_transform após o corpo. A
  composição pode ser compartilhada futuramente, mas não deve ser cacheada só
  pelo tick: ADS, arma, recarga e eventos podem mudar dentro do mesmo tick.
- Consultas de água, calibração e bind não devem ser cobradas assimetricamente
  num A/B. A correção desse viés já está documentada no relatório P1k.
- `move_and_slide` e separação entre bots permanecem fora desta alteração.

O relatório **histórico**, não um benchmark desta branch,
`FPP-TPP-P1K-CUSTO-20261106.md` em `f98c031`, registra regressão de pose no
ensaio Windows de 28 atores: mediana pareada +68,20% p50 e +56,42% p99, com
A/A instável. Não há aprovação de desempenho nem extrapolação para FPS.

## Decisão para a etapa B

| Alternativa | Implicação | Decisão |
| --- | --- | --- |
| Manter apenas deltas nos nós | Funciona no piloto atual; não fornece um resultado explícito consumível | Baseline preservada para comparação |
| Frame reutilizável dos dois pivôs locais | Centraliza composição absoluta e identidade tick/vida; permite testar paridade sem rede nova | Primeiro passo escolhido |
| Integrar imediatamente toda a retomada P1k | Altera fallback, binding e custo de 28 atores; ainda tem gate de performance reprovado | Adiada para integração seletiva e ensaio próprio |

O primeiro frame cobre **somente quadril e tronco do piloto offline local**.
Não é o PoseFrame completo de arma, IK e CollisionRig. Não muda autoridade,
protocolo, frequência física, LOD ou habilitação de bots/multiplayer. O tick
vem de `Engine.get_physics_frames`; não há relógio ou filtro adicional.
Os campos de tick/vida identificam o resultado, não são cache de estado nem
autorização para reutilizar a pose após um evento no mesmo tick.

O frame só deve ser alocado após o gate e pesos não neutros, conservando zero
alocações desse frame em OFF/remotos/bots. Transformações devem partir da base
reconstruída e preservar escala, orientação e offsets de montagem.

### Etapa B1 implementada e testada

`tactical_pose_frame.gd` guarda a base e o resultado absoluto dos dois pivôs,
mais tick físico e vida do ator. O adaptador existente calcula as intenções
R2A uma vez e publica as duas transforms desse frame. `WarLocomotion` aloca
o frame somente no primeiro caso elegível não neutro, reutiliza-o e invalida
sua identidade ao restaurar a base. Não foi acrescentado um cache por tick.
As identidades `.gd.uid` foram geradas pelo `ResourceUID` do próprio Godot.

Arquivos desta etapa:

- `modes/war/scripts/tactical_pose_frame.gd` e `.uid`: novo resultado reutilizável.
- `modes/war/scripts/tactical_world_body.gd`: composição absoluta antes da publicação.
- `modes/war/scripts/locomotion.gd`: armazenamento e invalidação do frame.
- `tests/realismo_r2c_pose_frame.gd` e `.uid`: contrato e integração local executáveis.
- Este relatório: auditoria, alternativas, resultados e limites.

Godot 4.7.2, headless, processos seriais, exit 0 em todas as execuções:

| Suíte | Verificações aprovadas |
| --- | ---: |
| Novo contrato/frame R2C | 129/129 |
| R2C original após a mudança | 105/105 |
| R2A | 33/33 |
| R2B | 93/93 |
| R1A | 8/8 |
| R1B | 13/13 |
| R1C matemático | 16/16 |
| R1C aterrissagem física | 10/10 |
| Ópticas | 242/242 |
| **Total** | **649/649** |

O novo teste cobre bases com escala/rotação, identidade tick/vida, um avanço
físico real, composição repetida sem drift, as montagens das **16** regiões,
invariância de arma/cano/câmera/cápsula e invalidação ao bloquear ADS, recarga,
crouch, prone, veículo, morte, remoto, bot e online. OFF, neutro e bot bloqueado
não alocam o frame. O cenário verifica que a configuração física continua 60 Hz.
Os testes de estados bloqueados não homologam a animação dessas ações nem ragdoll.

**Impacto de desempenho:** não medido em partida nesta etapa; não há alegação de
ganho ou aprovação de P99. O caminho ativo local acrescenta armazenamento de
transforms/identidade; o objeto é reutilizado. Bots/remotos continuam fora do
gate. A comparação A/A/A/B 0/12/22/28 permanece necessária antes de ampliar o
escopo, inclusive para avaliar o custo mínimo do novo campo por personagem.

Reprodução, em uma worktree com imports válidos, apontando `$godot` para Godot 4.7.2:

```powershell
$r2cProfile = Join-Path (Get-Location) 'work/r2c-profile'
& $godot --headless --path . --script res://tests/realismo_r2c_pose_frame.gd -- "--naval-data=$r2cProfile"
& $godot --headless --path . --script res://tests/realismo_r2c_world_pilot.gd -- "--naval-data=$r2cProfile"
```

As oito regressões originais foram executadas com as três flags R1/R2 ligadas.
O teste novo inicia com flags ambientais OFF para verificar alocação por padrão
e ativa/desativa o piloto explicitamente na fixture. Logs e resumo estruturado
ficam em `work/`; o patch e uma cópia deste relatório são entregues separadamente.

**Git:** o commit normal foi tentado com o hook habilitado. O `sh.exe` não conseguiu
criar seu objeto de sistema no sandbox (`NtCreateDirectoryObject`, `0xC0000022`),
impedindo a execução do hook. Nenhum hook foi desativado e nenhum commit foi
criado nesta etapa. O guard Python executado diretamente aprovou os sete
arquivos preparados, e `git diff --cached --check` passou; isso não substitui
nem burla a exigência do hook no commit.
As alterações ficam preparadas na branch local, sem push ou mudança na main.

A cópia temporária oculta `native/voice/bin/~libgodotopus.windows.template_debug.x86_64.dll`,
gerada pelo editor, tem o mesmo SHA-256 da DLL original. Sua remoção foi
recusada pela revisão automática por exigir aprovação de sandbox desabilitada.
Ela permanece untracked, fora do stage e do patch entregue.

## Importação: evidência separada

O editor frio ficou parado em criação de autoloads e registrou falhas de
`user://`; foi interrompido (exit 1). Não foi reproduzido um exit nativo
`-1073741819` nesta tentativa, nem demonstrada sua causa ou resolução.
Uma tentativa sem cache gerou recursos importados ausentes e foi descartada.

Para reproduzir a suíte runtime, foram copiados **somente 392 arquivos de
cache gerado** `.godot/imported` (80,3 MiB) da worktree R2C do mesmo commit
para esta worktree. Nenhum fonte/asset foi substituído. O runtime passou com
avisos de UID resolvidos pelo caminho textual. Isso **não homologa importação
fria**. Logs/perfis/cache ficam locais e não entram no commit.

## Gates seguintes

Após a paridade deste primeiro contrato: integrar seletivamente a fonte P1k
correta em outra etapa; provar as 16 regiões, arma e IK no mesmo estado/tick;
validar ações e transições; testar servidor e clientes ENet/DTLS até 1700 m;
medir A/A e A/B com 0/12/22/28 bots, Forward+, GTX 1650, 1080p Médio 100%,
FPS/P95/P99/física/poses/CPU/GPU. Essas aprovações continuam pendentes.
