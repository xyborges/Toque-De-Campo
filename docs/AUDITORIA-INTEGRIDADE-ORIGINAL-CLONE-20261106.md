# Auditoria de integridade — original × clone (06/11/2026)

**Conclusão delimitada:** o clone da `DESKTOP-R0I0NQG` contém integralmente os **5.156 arquivos versionados em comum** com a `main` do projeto original da `DESKTOP-JJ7U3G3`. Não houve arquivo comum ausente nem divergência de conteúdo após a normalização de quebras de linha. O clone **não** é uma reprodução completa dos builds, laboratórios, cache e materiais privados existentes apenas na máquina original. A verificação de runtime ocorreu no clone, não prova equivalência de desempenho entre hardwares.

## Fontes e commits auditados

| Origem | Branch | Commit | Arquivos rastreados | Mudanças locais |
| --- | --- | --- | ---: | --- |
| Projeto original, DESKTOP-JJ7U3G3 | `main` | `46b23f2ade0754c5635acb471339573183942899` | 5.156 | Nenhuma |
| Clone, DESKTOP-R0I0NQG | `main` | `4bff4ae9ed6a697ef1a61d2cba25425f03404a36` | 5.186 | Nenhuma |

Ambos apontam para `https://github.com/xyborges/Toque-De-Campo.git`. O commit do original é ancestral do commit do clone. Os **30 arquivos adicionais** do clone são dados brutos e documentação do benchmark GTX 1650 (sete rodadas); nenhum arquivo de `project.godot`, `modes/`, `maps/`, `scenes/`, `scripts/`, `assets/`, `audio/`, `shaders/`, `native/` ou outros subsistemas de jogo foi modificado nesses três commits.

## Método e resultado: comparação por conteúdo real

1. Listar, a partir do commit comum `46b23f2`, os caminhos versionados usando `git ls-tree -r --name-only -z` em ambas as máquinas, sem usar os nomes de arquivo como prova de igualdade.
2. Ler os arquivos **reais** de cada disco e calcular SHA-256 individual por caminho; registrar arquivo ausente e erro de leitura.
3. Comparar os 5.156 caminhos, tamanhos e hashes. Somente quando o hash bruto diferir, verificar se `CRLF -> LF` torna os arquivos integralmente idênticos. Essa normalização é **diagnóstica**, não altera arquivos nem autoriza mudar fontes binárias.
4. Verificar com SHA-256 bruto, sem normalização, os sete arquivos de navegação assinalados `-text -eol` no `.gitattributes`, bem como o manifesto da Favela, a cena principal e a DLL nativa de voz.
5. Verificar `git diff`, `git fsck --full --no-dangling` e a capacidade de iniciar o Godot no clone.

| Indicador | Resultado |
| --- | ---: |
| Arquivos comuns esperados e lidos em cada máquina | 5.156 / 5.156 |
| Arquivos ausentes | **0** |
| Erros de leitura | **0** |
| Hashes SHA-256 brutos idênticos | **4.711** |
| Diferentes apenas em quebras de linha `LF/CRLF` | **445** |
| Diferenças de conteúdo persistentes após normalizar `CRLF -> LF` | **0** |
| Diferença total de bytes nos arquivos comuns (clone - original) | -58.690 B |
| `git fsck --full --no-dangling` | PASS nas duas máquinas |

O checksum agregado dos **bytes brutos** é diferente, como esperado pelos 445 arquivos com formatos de fim de linha distintos:

- Original: `d137cc0219fce5f4705834093536e04690f714fcbe0327853040aaa83966cb5f`
- Clone: `b84b0a922b1e9c15d0676f1b01be7eecc0340d7fc346db978b10c3e36a4d36d1`

Configuração local do Git: original `core.autocrlf=false` e `core.eol=lf`; clone `core.autocrlf=true`. **Não reescrever arquivos automaticamente** só para igualar os checksums: os sete arquivos da navegação possuem exigência explícita de preservação exata de bytes. Todos os sete arquivos especiais comparados apresentaram SHA-256 bruto idêntico. O `maps/prepared/favela/manifest.json` também foi byte a byte idêntico (SHA-256 `FBBFAF0BB4230AE181993BB6BE8C3A6190BAAE55092BE2E7350B7917AB0CAF16`). A DLL `libgodotopus.windows.template_debug.x86_64.dll` foi idêntica (SHA-256 `E70E045962FBC5EF67B0C98BF398F0917899070F7D5A3F8C6AE7B5A15C23902A`).

## Capacidade de execução do clone

Na `DESKTOP-R0I0NQG`:

- Godot **4.7.2.stable.official** disponível e reconhecido.
- `--headless --check-only --script res://scripts/main.gd` — exit 0.
- `--headless --check-only --script res://modes/war/scripts/game.gd` — exit 0.
- `--headless --path <clone> --quit-after 60` — exit 0; cena principal iniciou e encerrou sem erro no console capturado.
- Benchmark oficial **Forward+, 1920×1080, médio, 28 bots, 60 s** em uma worktree derivada do mesmo código de jogo da `main`, com ajuste **somente no validador** (`c861d43`): coleta íntegra, 25,05 FPS médios e P99 de 55,25 ms. **Desempenho reprovado**, mas a simulação de Guerra foi realmente executada. O teste é de câmera fixa/offline, não prova rede, áudio ou jogo humano completo.

## Recursos existentes só no original (fora do Git)

A comparação não inclui arquivos ignorados e diretórios locais de distribuição, pois eles não fazem parte do código versionado. Inventário aproximado:

| Categoria | Original | Clone |
| --- | ---: | --- |
| `distribution/build/` | 4.464,7 MiB | Ausente |
| `distribution/published/` | 9.984,7 MiB | Ausente |
| `distribution/private/` | 81,1 MiB | Ausente |
| `work/` (laboratórios e coletas históricas) | 16.061,4 MiB | 1,1 MiB |
| `.godot/` (cache importado) | 90,7 MiB | 80,8 MiB |
| `.ai-coord/` (reservas e backups locais) | 324,7 MiB | 0,3 MiB |

Há ainda **25 arquivos ignorados** em árvores de código e ferramentas no original (sobretudo backups, arquivos temporários e `__pycache__`), contra zero no clone principal. Nenhum foi tratado como arquivo versionado obrigatório. **Não publicar materiais privados, credenciais, builds ou backups por padrão.** O registro `.ai-coord/` é local a cada máquina: não substitui a disciplina de branches exclusivas, PRs e revisão via GitHub para coordenação entre computadores.

## Limites para evitar falsos positivos

- **Comprovado:** integridade lógica dos arquivos compartilhados da `main`, binários críticos verificados, Git íntegro e execução básica com bots no clone.
- **Não comprovado:** clone com todos os artefatos de release/assinatura/deploy; paridade de caches, worktrees e testes temporários do original; equivalência visual e sonora plena; rede multiplayer completa; benchmark da Favela v25 após merge do runner.
- O novo mapa está em `ia/favela-concreto-densidade-escadas` (`7717aa5`) e **não** faz parte dos dois commits `main` comparados. Avaliá-lo separadamente, com commit explícito e teste no mesmo hardware, sem confundir com esta auditoria.
- O resultado de integridade **não** implica aprovação de desempenho. Continuar o gate de 60 segundos, verificando foco, 28 bots, GPU e cauda P95/P99.

**Decisão:** o clone é uma base confiável para desenvolvimento e benchmark do **código-fonte versionado**. Para publicar releases ou reproduzir ambientes locais antigos, fazer inventário e restauração seletiva dos recursos não versionados, com tratamento separado dos segredos.
