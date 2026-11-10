# Atualização 1.13.10 — candidata final (build 98)

**Data:** 10/11/2026. **Estado:** homologação final em andamento; **NÃO PUBLICADA** até confirmação pós-deploy. Branch isolada: `ia/release-11310-final-20261110`, worktree local `release-11310-ablate-stairs-20261109`. Referência: `main e8891ae`, servidor publicado `1.13.9/build 97`.

## Incluído na candidata

- **Favela:** 253 caminhos de terra conectando portas residenciais a vias e becos, mapa com 4.313 casas, 142 lajes transitáveis e 49 rotas.
- **Bots:** fuga de obstáculos, escolha de cobertura contra blindados ocupados, limite temporário de **11 bots por equipe** no Guerra (e 22 bots no Battle Royale). QA ainda pode simular 28 bots; esse limite não deve ser anunciado como melhora de FPS por otimização de código.
- **Áudio:** presença de tiros e explosões distantes, compressor de transientes no barramento de explosões e limitador Master; nenhum arquivo WAV ou MP3 regravado.
- **Textos:** validação de UTF-8 para atualizações, manifesto e histórico do site.
- **Biblioteca:** asset estático Caveirão cinza integrado, importável, **não dirigível**.
- **R2C/PoseFrame:** herdado da main como **piloto experimental DESATIVADO** para produção/multiplayer, sem anunciar realismo ativo.

## Escadaria em Z — adiada por desempenho

A escadaria de 276 degraus e seis patamares continua preservada na branch `origin/ia/favela-z-stairway-20261109` e na candidata de desenvolvimento `ia/release-11310-candidate-20261109`. **Não entra na 1.13.10.** O teste visual e físico passou, mas o benchmark revelou regressão de frame pacing.

Benchmarks A/B reais no JJ7, GTX 1650, Forward+ 1920×1080, Médio 100%, 28 bots, 35 s + 10 s de aquecimento, foco integral:
- main `e8891ae`: 45,3 e 45,5 FPS médios; P99 **37,4 / 35,2 ms**.
- candidata com escadaria: 42,6 e 41,0 FPS médios; P99 **43,5 / 53,1 ms**.
- mesma candidata **sem escadaria**: P99 **35,6 ms**; 28 bots e foco integral, import exit 0.
- Testes posteriores na worktree experimental de otimização: colisão trimesh compactada P99 **55,2 ms**; pequenas rampas agrupadas P99 **47,4 ms**. Ambas reprovadas; **não foram integradas** à candidata final.

Conservar a escadaria para investigação de LOD/custo gráfico/colisão em versão futura. Não prometer correção do problema das lajes V27; a queixa de tremor permanece sem reprodução conclusiva.

## QA já verificado durante a coleta integrada

- Godot 4.7.2 import exit 0, UTF-8 4/4 PASS.
- Sem regressão lógica da Favela: caminhos 253/253, smoke do mapa PASS.
- Guerra limite de população 17/17, Battle Royale 3/3, recuperação e cobertura de bots 10/10.
- Mixer real presença 103/103 e dinâmica de explosões 25/25.
- R2C opt-in OFF: PoseFrame 129/129, estados 172/172 e mundo 105/105.
- Favela ENet 2 clientes: 12 + 6 + 6 PASS.
- Ucrânia e Favela ENet/DTLS, 28 bots e explosões: 72/72 em cada mapa (144/144), GTX 1650 1080p Forward+, áudio PCM sem clipping. Instrumentação corrigida para contar apenas IDs da matriz controlada, separando explosões ambientes dos bots.
- **Revalidação da fonte final sem escadaria, 10/11/2026:** importação Godot 4.7.2 exit 0; 253 caminhos e smoke Favela PASS com 11.624 colisores; limites de bots 17/17; fuga/cobertura 10/10; presença PCM 103/103; explosões 25/25; ENet Favela servidor + alpha + bravo 12+6+6 PASS. ENet/DTLS com 28 bots e áudio real na fonte definitiva: **Ucrânia 72/72 e Favela 72/72 PASS**, com cliente GTX 1650 Forward+ 1080p e zero clipping no Master. A suíte de UTF-8 atual passou 4/4.

## Limites e segurança

O FPS com 28 bots continua abaixo de 60 na GTX 1650; não alegar otimização geral. A meta de P99 abaixo de 33,3 ms não foi homologada. Os direitos de redistribuição das seis músicas já presentes na Favela não foram verificados nesta rodada.

**Critérios restantes:** testar a fonte final, confirmar manifesto Favela v30/68 fontes, commit e integração revisados, preparar build 98 assinada no diretório oficial com chaves existentes, QA de instalação, preflight antes de upload, deploy protegido e conferência do manifesto HTTPS e serviços. Nenhuma alteração no servidor deve preceder esses gates.

**Publicação:** PENDENTE. Atualizar apenas após provas reais de deploy.
