# Revisão do sistema de ópticas — 03/11/2026

## Escopo implementado

- Compatibilidade modular entre AK, FAL, G3 e Sniper e todas as 4 lunetas disponíveis: Prismática 4×, PSO 4×, Hensoldt ZF 4×24 e Telescópica 8×.
- A Sniper agora usa `assets/weapons/sniper_iron.glb`, variante própria sem a luneta fixa do modelo anterior. O `sniper.glb` original foi preservado. A nova mira de ferro é uma montagem separada (`scripts/sniper_irons.gd`), visível quando nenhuma óptica está instalada.
- Luneta 8× implementada em `scenes/weapons/precision8x.tscn`, `scripts/attachments/data/precision8x.tres` e `shaders/scope_precision8x.gdshader`. Pode ser usada em qualquer rifle compatível, sem exclusividade da Sniper.
- Hensoldt 4× com tubo clássico, retículo próprio e suporte de garras adaptado a G3 e plataformas com trilho. As montagens foram revistas em capturas 3D reais.
- Mesmos encaixes, recursos, validação de tamanho/interface, modelos 1ª/3ª pessoa e pipeline de `SubViewport` existente (384×384). Não foi criado um novo sistema de ópticas.
- Loadouts, perfis de arma, menu e preferências por rifle aceitam as miras específicas; IDs antigos como `scope4x` continuam migráveis; remover a mira fica salvo. A Sniper não ganha luneta automaticamente.
- A mira 8× usa ampliação de fato 8× e sensibilidade de ADS reduzida (0,125); as miras 4× usam 0,25.
- Cópias de ópticas de outros jogadores não alocam `SubViewport` adicional. O cano, o recuo e a balística não foram alterados.
- Corrigida a postura da Sniper com mira de ferro e jogador deitado: braço esquerdo não estica além do limite no ADS.

## Verificação e regressão

- `tests/optics_universal_validation_20261103.gd`: 294 verificações com renderização OpenGL real, 0 falhas. Inclui todas as combinações dos 4 rifles com as 4 miras, ADS, sensitividade, geometria do socket, troca e remoção, mira de ferro da Sniper e estado remoto de arma.
- `tests/prone_weapon_pose_validation.gd`: 1.126 verificações, 0 falhas. Testa postura deitado, movimento do cano, mira, recarga e braço da Sniper.
- `tests/optic_preferences.gd`: 9 verificações, 0 falhas. Inclui contas mock, reentrada, persistência da 8× e opção Sniper sem luneta.
- `tests/scoped_muzzle_regression.gd`: 490 verificações, 0 falhas na regressão anterior desta implementação.
- `tests/war_spawn_attachment_crash_regression.gd`: 319 verificações, 0 falhas na regressão anterior; inclui vários ciclos de morte/respawn e desmontagem de armas.
- `tests/optic_catalog_validation.gd`, `tests/attachment_framework_validation.gd`, `tests/optics_transport_validation.gd` e `tests/br_optic_inventory_validation.gd`: aprovados. O teste BR teve uma antiga asserção de quantidade de loot corrigida para validar âncoras reais sem supor apenas um item por ponto.
- Capturas reais geradas no diretório `work/optics-review-*.png`.

## Limites que permanecem

- O teste completo com múltiplos processos `tests/equipment_network.gd` não foi concluído: a máquina de desenvolvimento não tinha o certificado DTLS local de teste (`/etc/toque-de-campo/game-tls/server.crt`). Não alterei `scripts/secure_transport.gd` nem desabilitei TLS para fazer passar.
- O estado remoto e sua reconstrução visual foram testados localmente, mas não houve aprovação de uma partida real com dois clientes conectados por DTLS.
- Não foi realizado benchmark controlado de FPS com 28 bots após essa atualização, nem publicação/exportação de novo executável.

## Regeneração do modelo

O script `tools/create_sniper_iron.py` pode regenerar `assets/weapons/sniper_iron.glb` a partir do `sniper.glb` original. O original permanece disponível. Não alterar manualmente a geometria do asset original para manter a reversibilidade.

## Rollback

As alterações cirúrgicas originais do sistema de ópticas antes desta revisão estão arquivadas em `work/optics_pre_20261103/`. Reverter a implementação exige reaplicar seletivamente esse backup; atenção a alterações posteriores de outros chats.
