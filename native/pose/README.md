# WarNativePoseMath — piloto GDExtension C++

**Estado:** laboratório isolado, não integrado à movimentação de produção.

A classe nativa `WarNativePoseMath` implementa:
- `upper_transform(pitch,lean)`: mesma matemática de `GameInfantryPose.upper_transform`, sem usar scene nodes.
- `weapon_transform(aim_pitch,lean,prone_weight,body_root,offset)`: mesma transformação de `GameInfantryPose.weapon_pose`; o chamador continua responsável pelo `clamp_aim_pitch` e recuo.
- `upper_batch(pitches,leans)`: processa até 28+ transformações em uma chamada. Faz cópia de resultados no retorno; compare custo end-to-end.

O código NÃO movimenta personagens, não muda poses de hitbox/solver, não altera ragdolls, física, RPC, redes, cliente ou servidor.

## Windows
O projeto usa Godot 4.7.2 (precisão single) e C++ oficial `godot-cpp`, compilador Microsoft Visual C++ (VS BuildTools 18), Python e SCons.

Clonar `https://github.com/godotengine/godot-cpp.git` **fora da pasta versionada**. Configurar `GODOT_CPP_ROOT` com o caminho da clone. No terminal de desenvolvedor do Visual Studio, navegar até `native/pose` e executar:

```powershell
python -m SCons platform=windows target=template_debug -j4
python -m SCons platform=windows target=template_release -j4
```

Compila DLL x64 sob `native/pose/bin/windows/`. Não enviar projeto sem variantes do sistema operacional alvo. No Linux o .gdextension precisa de entradas `linux.*` e binários .so feitos com toolchain compatível para habilitação segura.

## Testar
```powershell
godot --headless --editor --path . --import --quit
godot --headless --path . --script res://tests/gde_pose_parity_qa.gd
godot --headless --path . --script res://tests/gde_pose_microbench.gd
```
A primeira QA compara **900 estados de torso/arma usando funções reais de `GameInfantryPose`** e 28 cálculos em lote. Deve falhar em classes ausentes, transformação divergente ou erro de script. A segunda mede GDScript vs chamada nativa individual vs pacote de 28 no mesmo processo; **não mede FPS/CPU de 28 bots reais**.

### Gate de integração
É obrigatório ter QA de equivalência de tiros/hitboxes autoritativos e benchmark A/B com servidor + cliente GTX1650 a 1080p, sem outros testes, antes de ativar nos scripts de gameplay. `GameInfantryPose`, `WarPlayer`, `GamePlayer` e `WarCollisionPoseSolver` não são modificados neste experimento. Não mesclar a branch diretamente para main enquanto faltarem binários Linux/macOS/Windows de distribuição necessários e fallback.

## Atualização do piloto (10/11/2026)
Os cálculos `upper_transform` e `weapon_pose` do `GameInfantryPose` agora possuem caminho GDE **opcional** por `--pose-gde-pilot`. O padrão continua GDScript; quando a classe nativa não está disponível, as funções usam o código original.
- Teste matemático: 1.830 verificações aprovadas, 900 posturas e pacote de 28.
- Teste do caminho realmente chamado pelo jogo: 842 verificações em cada uma das opções (padrão e opt-in).
- Teste de 28 bots headless, 2 pares A/B com ordem invertida: nenhuma falha, **sem melhoria consistente do P95 de frame**. Não habilitar por padrão ou em release ainda.
- GDE C++ em lote calculou 4,17x mais transformações/s que GDScript no microbenchmark, mas **o pacote de 28 não está conectado ao sistema de jogo**; a integração atual usa chamadas C++ individuais (1,68x no microbenchmark). Não confundir com ganho de FPS.

## Linux x86_64 (compilação experimental)
Usar `GODOT_CPP_ROOT` como caminho para `godot-cpp` oficial e executar:
```bash
cd native/pose
GODOT_CPP_ROOT=/caminho/godot-cpp scons platform=linux target=template_debug -j4
GODOT_CPP_ROOT=/caminho/godot-cpp scons platform=linux target=template_release -j4
```
Os binários esperados são `native/pose/bin/linux/libwarpose.linux.template_debug.x86_64.so` e `libwarpose.linux.template_release.x86_64.so`. Validar com Godot 4.7.2 Linux e em **ambiente com a mesma versão de glibc/libstdc++ que o servidor dedicado** antes de lançar. O WSL da máquina de desenvolvimento usa Ubuntu 26.04; compilar nele não garante compatibilidade com Ubuntu 24.04 ou mais antigo.

Testes portáveis:
```bash
godot --headless --path . --script res://tests/gde_pose_platform_smoke.gd
godot --headless --path . --script res://tests/gde_pose_runtime_qa.gd -- --pose-gde-pilot
```
