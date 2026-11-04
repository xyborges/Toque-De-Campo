# Atualização corretiva 1.5.1

Publicada no Ubuntu em 23/10/2026: versão 1.5.1, build 21. Assinatura, instalador real, download sem repetição, inicialização do executável e proteção dos arquivos privados foram verificados. Guerra segue em implementação local; cartão desabilitado por `gameplay/war_enabled` até sua validação completa.

## Causas e alterações

- Entrada tardia criava avatar com `life_id=1`, mesmo após respawn. Snapshots da vida atual eram descartados. Agora o servidor envia uma referência confiável da vida e estado de cada jogador existente, preservando a rejeição de snapshots antigos.
- Voltar fechava o único painel naval e deixava o fundo cinza. Voltar/Esc agora retornam ao menu; remoção da cena ocorre fora do despacho de entrada. Sessão compartilhada já validada não reabre o login; sessão em disco continua consultando o servidor. Gerações descartam respostas de sessão anterior.
- Timer de respawn, conexão cancelada, referências de áudio/efeitos e controles não podem atravessar a saída da partida.
- FAL tinha quatro vozes para amostra de 2,30 s. Pool por emissor/arma até 24 vozes e 96 globais, reciclando a cauda mais antiga. Áudio local imediato, deduplicado na confirmação. Cadência conserva fração do passo; servidor tolera até 45 ms de variação sem aumentar taxa média.
- Cor e quatro proporções passam ao perfil autenticado. API aceita cor hexadecimal e proporções finitas entre 0,65 e 1,50. Aparência não modifica saldo/compras. Migração inicial do personagem local e isolamento entre contas.
- Ragdoll testa deslocamento da pose inteira para evitar nascer penetrando paredes além da cápsula de movimento. Limites passivos de velocidade, acessórios e roupa presos às partes físicas.
- Míssil 86,52 → 90,846 m/s; torpedo 42 → 44,1 m/s. Mesma configuração na previsão e simulação.
- Sniper 92 → 105,8 m/s; gravidade 9,81 → 8,3385 m/s². Sem impulso para cima ou compensação artificial.
- Sons originais gerados por `tools/generate_combat_feedback.py`: dano, quase acerto e carregador vazio. Posição 3D e limite de vozes/frequência; disparo próprio não produz quase acerto.
- Traçantes: Glock azul claro, FAL âmbar, sniper rosa claro, avançando com a própria munição.
- Expansão da imagem à proporção da janela remove faixas laterais.

## Testes locais

- Menus nativos: 10 verificações, cliques em Voltar e alteração de sensibilidade/volume.
- Login: 44 verificações, backend real, sessão válida/revogada, timeout, logout e três resoluções até 1920×1080.
- Entrada tardia: servidor e dois clientes; cliente tardio recebeu vida 2, observou 2,34 m de deslocamento e 21 disparos.
- Rede: três processos ENet, atraso 20–70 ms, 8% de perda configurada. Dano, morte, respawn, recarga, movimento, mira, reconexão e áudio de morte passaram.
- Regressão: lobby naval 18, física naval 15, combate 86, armas brancas/NPCs 73 e ragdoll quatro verificações.
- Ragdoll junto a paredes: 12 corpos, proporções variadas e braços em pose. Pico 5,86 m/s; altura máxima 2,00 m; separação máxima torso/parte conectada 1,34 m; nenhum lançamento ou separação indevida.
- Feedback nativo: 12 verificações. FAL completou exatamente 30 disparos ao segurar, sem disparo extra; áudio, cores, velocidades e limpeza passaram.
- API PHP/SQLite isolada: 12 verificações de persistência, duas contas, nova sessão, isolamento, limites, proteção de saldo, escrita sem sessão e token revogado.

Esses resultados validam a atualização corretiva. A medição separada de Guerra está em `GUERRA-DESEMPENHO.md`; o modo permanece desabilitado na distribuição até concluir sua validação.

## Validação da publicação

- `work/hotfix-151-deploy.log`: VERIFIED_READY e DEPLOYED build 21.
- `work/hotfix-151-distribution.log`: instalação pelo executável baixado da VM, verificação da assinatura e segunda execução sem baixar novamente.
- `work/hotfix-151-real-pvp.log`: dois clientes autenticados reais, disparos e estado da partida.
- `work/hotfix-151-real-naval-source.log`: multiplayer naval com o código-fonte atual aprovado. O primeiro teste usou pacote QA desatualizado e foi descartado; o pacote QA deve ser exportado novamente antes da próxima rodada.
- `work/appearance-roundtrip.stdout.log`: oito verificações contra a API real, incluindo perfil em outro dispositivo e rejeição de proporções inválidas.
