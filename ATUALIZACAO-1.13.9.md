# Atualiza??o 1.13.9 ? Favela v26, HUD unificado e efici?ncia headless

**Estado inicial:** candidata em revis?o em 08/11/2026. **Build planejada:** 96 (anterior publicada: 95 / 1.13.8).

## Conte?do

- Favela v25 j? integrada: 4.313 casas, 31 lances de escada, 217 degraus f?sicos, setores A?E e contra-ataque; Favela v26 corrige o tremor nos pontos de pouso das lajes.
- Dashboard de partida unificado para Guerra, Favela, Battle Royale, Naval e arena; dados autoritativos preservados.
- Otimiza??o de inicializa??o somente em servidor dedicado da Favela: elimina c?lculo de arbustos, capim e rochas **visuais**, conserva ?rvores e todos os colisores f?sicos. Kill switch TDC_IA2_HEADLESS_SKIP_VISUAL_HILLSIDE=0. N?o ? ganho de FPS do cliente.

## Limites e decis?es

- N?o integrar acelera??es de poses/IK, movimento de bots, limita??o de ticks ou cache de terreno/lotes desatualizado. A/B gr?fico n?o aprovou ganho consistente em FPS/P99.
- As tr?s flags existentes de arma remota, ragdoll adiado e limite estrito de corpos continuam desligadas por padr?o.
- Os testes ser?o registrados antes de promover para a main e publicar no Ubuntu. N?o confundir merge GitHub com publica??o assinada.

## Compatibilidade

- Godot 4.7.2, Jolt, renderizador Forward+ desktop e Compatibility na Web preservados.
- Seis m?sicas do baile existentes preservadas, sincronizadas e aud?veis at? 100 m.
- Preservar contas, servidor, VMs, certificados e hist?rico assinado. N?o executar deploy fora do pipeline oficial.

## QA executado em 08/11/2026

- **Godot 4.7.2 importa??o inicial:** exit 0, sem erros de script.
- **Su?te local:** 14 execu??es exit 0: vegeta??o headless, dois smoke tests servidor ON/OFF, lajes V26 (142/142, sem recuos/c?psulas bloqueadas), 28 bots/8 ve?culos (39/39), Linha de Frente (63/63), baile (102/102 e 120/120), dashboard (11/11), menu (22/22), arquitetura (9.491 amostras), atmosfera (40.753 checagens), vias e concreto/densidade (261/261).
- **Multiplayer real QA:** servidor e dois clientes ENet/DTLS 16/16 no contra-ataque e 18/18 com 28 bots e dois humanos, otimiza??o headless ON. Sem mudan?as em autentica??o real de produ??o.
- **Otimiza??o headless:** trecho isolado de 830,268 ms para 75,003 ms; ?rvores id?nticas por SHA256; smoke dedicado 3.980 ms ON vs 4.779 ms OFF numa compara??o isolada (n?o ? estimativa de FPS ou benef?cio m?dio estat?stico).
- **Manifestos:** Favela v27 e Ucr?nia v22: todos os arquivos de origem existem e source_hash/content_hash conferem; substitu?do script removido do HUD pelo dashboard unificado.
- **Avisos n?o bloqueantes:** algumas fixtures headless emitiram '1 resources still in use at exit' com exit 0; acompanhar.
- **Gate GTX 1650:** 60 s, 1080p, M?dio, 28 bots: **COLETA INV?LIDA por foco 0%**. FPS observado 27,4 e P99 69,9 ms N?O s?o compara??o homolog?vel. Piloto de 10 s teve foco 1,7%, tamb?m inv?lido. N?o alegar cumprimento da meta 60 FPS/P99 nem regress?o causal de cliente.
- **Limita??o f?sica:** teste V26 demonstra elimina??o das colis?es coplanares; a aus?ncia de tremor em multiplayer com jogador humano real ainda requer playtest.
