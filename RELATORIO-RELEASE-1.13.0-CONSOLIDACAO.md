# Auditoria final — candidata 1.13.0 (03/11/2026)

**Situação: pacote local pronto, publicação na VM Ubuntu BLOQUEADA por testes de integração.**

- Publicado atualmente no Ubuntu: **1.12.0 / build 84** (consulta preflight ao servidor)
- Candidato montado localmente: **1.13.0 / build 85**
- Gerado com `distribution/ubuntu/publish_ubuntu.py --version 1.13.0 --prepare-only`; **nenhum envio/ativação remota**.
- Cliente Windows protegido: exportado; ZIP **242,48 MiB**; Linux Server exportado; release assinado; **10/10 hashes do manifesto servidor conferem**.
- Inicialização simples do jogo exportado: **exit 0, 5 segundos**. Teste com script QA externo no executável protegido: **timeout após 55s, sem relatório**. Não equivale a teste de partida.
- `distribution/ubuntu/preflight.py`: PASS, remoto build 84 e candidato build 85.
- Preflight de mapas somente leitura: **Afeganistão v10, Ucrânia v13, Deserto v7, Escritório v7 e Naval v7 READY**.

## Modificações consolidadas

- **Armas:** G3 no modo Guerra; AK/FAL/G3/Sniper com Prismática 4x, PSO 4x, Hensoldt 4x, Precision 8x e Sniper com mira de ferro.
- **Som/VFX:** novo kit near/far de granada/tanque/drone, G3 near/far, propagação 3D e efeitos de fumaça persistente/ondas de choque.
- **Mapas/BR:** mais cobertura rural no Afeganistão (12 abrigos,32 muros,84 detalhes), +12 locais de loot, spawn variado, rotas reconstruídas 12/12.
- **IA:** melhor seleção de alvos, emprego de blindados, granadas, defesa de pontos e resgate de NPCs; continua em **28 bots**, não em 57.
- **HUD e skins:** navegação e UI unificadas, correção de testes desatualizados de classe com G3; mangas/rig afegão aprimorados.
- Testes: ópticas 294/294, prone 1.126/1.126, UI BR 41/41, HUD classes atual 52/52, explosões 33/33, G3 PASS, preferências de ópticas PASS, mapas PASS.

## Trabalho em laboratórios e desempenho

- Foram auditadas as cópias independentes `campo-perf-lab-20261103` e `campo-perf-lab-20261103-threaded`. Elas são snapshots anteriores às edições principais mais recentes e não podem ser copiadas por cima do projeto: 50/51 arquivos diferem do MAIN, sobretudo porque armas, áudio, bot, HUD e mapas mudaram depois das cópias.
- Na comparação **headless** 28 bots, média de frame **17,03ms single** contra **18,82ms threaded**; nenhuma evidência de ganho do modo threaded nessa amostra, e estes números não são FPS gráfico.
- No laboratório gráfico do Afeganistão a **1920x1080 / GTX1650 / 28 bots**, Compatibility: **18,2 FPS de mediana, p95 106,3ms**. Forward+: **54,5 FPS de mediana, p95 77,5ms**. Outra amostra Forward+ com throttling: **33,1 FPS mediana, p95 102,3ms**. **Todos apresentam engasgos**; medições de laboratório anteriores à conclusão do projeto 1.13, sem benchmark da build 85 exportada.
- Manter o Compatibility como fallback, e não adotar configurações experimentais como se fossem melhora comprovada. Não realizar merge automático do laboratório.

## Gates que impedem lançamento externo

1. Duas máquinas, dois clientes completos exportados e servidor com a **mesma versão dos mapas**: Guerra + BR precisam passar entrada, baseline, implantar, matar/morrer, respawn, desconexão/reconexão.
2. Regressão de desempenho e estabilidade gráfica **na build 85** a 1080p com **28 bots**, movimentação e combate, além de verificar travadas graves e limitações térmicas.
3. Fullscreen, áudio/voz real, efeito de explosões e ciclo completo de updater com pacote assinado + rollback.
4. Testar integridade do estado e logs em uma implantação piloto. Não desabilitar verificação de hashes/compatibilidade ou DTLS para contornar erro.

## Localização, rollback e controle

- Documento público/técnico: `ATUALIZACAO-1.13.0-RASCUNHO.md`.
- Notas em formato do launcher: `distribution/release-notes.json` e `distribution/release-notes-1.13.0-draft.json`.
- Artefatos **não ativos na VM**: `distribution/build/ubuntu`; ZIP `distribution/build/release.zip`.
- Backups das configurações/manifestos da build anterior: `work/release113-rollback-original`.
- Não há `.git` no projeto. Para reverter o desenvolvimento, restaurar arquivos seletivamente de backups específicos; **não copiar snapshots inteiros dos laboratórios por cima do MAIN**.
