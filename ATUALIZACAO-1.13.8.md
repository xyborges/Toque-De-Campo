# Atualização 1.13.8 — Favela, baile sincronizado e Forward+

**Estado:** PUBLICADA — 1.13.8 / build 95 ativa no Ubuntu desde 06/11/2026; verificação pós-deploy aprovada.

Data: 06/11/2026. Worktree de integração: `ia/release-1138`.

## Alterações integradas

- `6365b2e` / `5a6bc65`: renderizador Forward+ padrão no Windows; Compatibility preservado na Web.
- `d2762f9`: quadra de futebol, palco, treliças, refletores, paredão, DJ e colisor físico compartilhado.
- `4ced39e`: sincronização das seis músicas existentes por semente e relógio da operação, sem tráfego extra de áudio; fonte na posição real do palco e corte em 100 m.
- `59f3f55`: merge da branch descendente `ia/favela-baile-sync-perf` sobre a base da `main`; inclui ambos os commits do baile.
- Favela: manifesto preparado **v17**, 61 fontes com hashes verificados (inclui correção de contato visual/físico no piso da quadra).

## QA realizado na candidata

- Godot 4.7.2: importação a quente PASS; a primeira importação de cache vazio terminou após reimport com erro de acesso à memória, sem erro de script. Importação repetida exit 0.
- `favela_baile_qa.gd`: **120/120 PASS**, 104 `StaticBody3D`, paridade cliente/servidor.
- `favela_baile_sync_qa.gd`: **102/102 PASS**, seis faixas, ordem determinística, offset e corte espacial.
- `favela_runtime_qa.gd`: **37/37 PASS**, oito veículos sem sobreposição.
- `favela_menu_release_qa.gd`: **22/22 PASS** após atualização do manifesto.
- `favela_operation_smoke.gd`: **PASS** após ajustar a borda da quadra, que invadia a mini-rua 5.
- `favela_road_collision_1138_qa.gd`: **PASS**, zero colisores bloqueando a mini-rua 5 (antes: três amostras do piso).
- ENet/DTLS: servidor local e dois clientes reais exit 0, testes 12+7+7 PASS.
- PCM nativo Forward+ / GTX 1650 no mapa inteiro: **8/8 PASS**, medição no trecho audível do arquivo a 3, 30, 60 e 90 m; reprodução parada a 110 m. Fonte posicionada no paredão.
- Uma faixa MP3 original contém silêncio entre aproximadamente 3–10 s; arquivos fornecidos não foram modificados. O primeiro diagnóstico confundiu esse silêncio com falha do decoder; tentativas experimentais de alteração de playback foram revertidas antes da release.

## Limites e pontos de acompanhamento

- Verificar direitos de redistribuição das seis músicas já incluídas em builds anteriores; esta revisão não altera, recria nem adiciona gravações.
- A instalação assinada, o preflight e a verificação de manifesto/serviços foram aprovados. A meta de 60 FPS estáveis em 1080p com 28 bots ainda não foi revalidada especificamente na build 95 com um benchmark completo de partida.
- Não incluir as branches de CollisionRig/FPP experimental, ainda com gate de performance pendente.

## Publicação oficial — 06/11/2026

- Commit de integração na `main`: `fb62ed2`. Pacote local assinado: `SIGNED_UBUNTU_RELEASE 95`, versão `1.13.8`, 11 artefatos declarados.
- Instalação de QA do pacote assinado: **13/13 PASS**. Executável Windows protegido iniciou com exit 0, DLL de áudio carregada e hashes EXE/PCK intactos.
- Preflight autenticado: `PREFLIGHT build=95 publicado=94`, `PREFLIGHT_OK build=95`.
- Helper de deploy: `VERIFIED_READY build=95`, `DEPLOYED build=95 version=1.13.8`, sem desativar a proteção de partidas ativas.
- Verificação read-only pós-deploy: `LIVE_1138_VERIFICATION` **8/8 PASS**; manifesto HTTPS idêntico ao assinado, symlink `/opt/toque-de-campo/current` em `build-95`, executável e PCK Linux com SHA-256 esperado.
- Seis serviços systemd ativos: `toque-war`, `toque-war-afghan`, `toque-war-favela`, `toque-br`, `toque-naval` e `toque-pvp`. A porta UDP 3017 está em escuta.
- Manifesto público: `1.13.8 / build 95`. Download na rede local: `https://192.168.101.24/`.

Evidências: `work/release1138-prepare.log`, `work/release1138-signed-install.log`, `work/release1138-preflight.log`, `work/release1138-deploy.log` e `work/release1138-live-verification.log`. Os logs ficam ignorados pelo Git.

**Publicado e verificado no servidor oficial.** A validação não equivale a um teste auditivo humano em partida online com dois clientes nem a um benchmark completo com 28 bots. O GitHub não recebeu push nesta etapa.
