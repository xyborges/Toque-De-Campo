# 1.10.0 — Battle Royale no Deserto Afegão

Publicada no Ubuntu em 29/10/2026 como **build 71**. Cliente Windows protegido, pacote Linux, site, notas, API e os quatro serviços foram ativados juntos. O banco de contas foi preservado e copiado antes da ativação. Nova Grama experimental e pedras extras nas encostas continuam fora da atualização.

## Conteúdo

- Battle Royale individual no mapa afegão: interiores exploráveis, loot contextual, bots, zona, socos, proteção e mochilas 1/2/3, espectador, resultados e nova rodada. Pareamento fixo de 30 segundos; sala iniciada fecha admissão. Duas partidas simultâneas configuradas nesta VM de 8 GB, com limite de memória de 4 GB para o serviço BR e seus filhos.
- Inventário com CHÃO/MOCHILA/ARMAS/EQUIPAMENTO, lista mista e menus Usar/Equipar/Recarregar/Largar. Troca da arma atual com dois espaços ocupados preserva munição e módulos no chão.
- Prismática e PSO 4× intercambiáveis em AK/FAL, com lente ao vivo e arquitetura modular de acessórios, sem duplicar modelos-base. Futuras categorias exigem seus próprios modelos e comportamentos; não entram como itens fictícios no loot desta versão.
- Corpos BR persistem até o fim da rodada. Saquear mochila, colete ou capacete retira sua geometria para todos. Posição final sincronizada, física congelada após estabilizar e persistência após desconectar. Pilhas grandes de munição e curativos conservam as quantidades.
- Voz por proximidade com X para sobreviventes, dispositivo/volume/silêncio e codec Opus no cliente. Servidor Linux retransmite sem codec.
- Personagem articulado compartilhado, recarga da AK revisada, socos e posturas BR, ajustes nas ópticas e maior dano da granada compartilhada.

Documentação anterior do conjunto BR: `docs/BATTLE-ROYALE-CONCLUSAO.md`, `docs/BR-PAREAMENTO-E-REVISAO.md` e `docs/INVENTARIO-MODULAR-E-CORPOS.md`.

## Casas e terreno da Ucrânia

O porto leste continha uma segunda instância de `detalhamento_190.tscn`, já presente na camada global. O deslocamento do porto duplicava 20 fachadas e os demais detalhes, inclusive fora da ilha; seus nivelamentos também criavam elevações artificiais. Foi removida apenas essa instância duplicada, preservando a cena do porto e os detalhes originais.

O nivelamento dos bairros passou a considerar a altura final das ruas e da costa. As fundações recebem patamares locais com transição, reservando o corredor dos acessos portuários. Vinte e cinco objetos conservados na cena tiveram somente a altura ajustada ao terreno atual. Não houve regeneração integral das cenas editáveis.

Auditoria de **122 construções originais**, sem duplicação: diferença máxima entre referência e apoio de 0,224 m, variação máxima sob a planta de 0,736 m suportada pelas fundações e acesso amostrado abaixo de 40°. Antes, havia apoios com mais de 13 m de variação e fachadas sobre elevações de até 65° no entorno.

Teste com Guarani percorreu os dois acessos inteiros nos dois sentidos, com colisões reais, sem travamento, lançamento ou tombamento: **12 verificações aprovadas**. Inclinação longitudinal máxima amostrada: oeste 5,94%, leste 7,51%; transversal: 1,05% e 3,11%. Isso é validação física, não benchmark de FPS.

Evidências: `work/ukraine-building-sites.json`, `work/ukraine-building-conform.json`, `work/roads192-results.json` e capturas `work/ukraine-1100-*.png`.

## Blindados dos bots

O planejador anterior só procurava veículos. Agora consulta infantaria aliada em uma grade espacial compartilhada, prevê cruzamentos e calcula a distância de frenagem conforme a velocidade. Há freio explícito, reserva do corredor completo do casco, mais antecedência e margem lateral para ultrapassar. Quando não há espaço, o bot aguarda; a recuperação de ré também considera aliados atrás.

**25 verificações aprovadas** com física real: Guarani, BMP-2, Abrams e T-90 a 8 m/s pararam diante do aliado, mantendo 100 de vida e 9,92–11,10 m entre os centros. Um Guarani completou a passagem por um Abrams parado, com separação lateral mínima de 7,24 m; flancos bloqueados exigiram parada. Atropelamento físico de inimigo continuou causando morte. O código de dano não foi removido ou filtrado para esconder o problema.

Decisões são reaproveitadas por 120 ms, inclusive resultado vazio; a grade de atores atualiza a 5 Hz. O mesmo diretor autoritativo atende offline e bots online. Evidência: `work/war-bot-friendly-traffic.json`.

## Instalação e publicação

**Baixar novamente o atualizador uma vez:** o launcher antigo só aceitava EXE/PCK; o novo pacote inclui também a DLL release do Opus. O novo launcher aceita as versões antigas e a lista fechada dos três arquivos, verificando assinatura, tamanho e SHA-256. Rejeita bibliotecas extras, nomes arbitrários, duplicação de entradas e travessia de diretórios. Preferências e contas ficam fora das pastas de versões e são preservadas.

Novo suporte administrativo de publicação do BR instalado após autenticação SSH/sudo. O helper valida a unidade exata do BR, inclui seus processos nas verificações de ocupação, exige heartbeat e socket corretos, e inclui o serviço no rollback. Liberações de firewall: UDP 3016 e 3020–3021. As regras e serviços existentes foram preservados.

- `work/publication1100-activation.log`: `DEPLOYED build=71 version=1.10.0`.
- `work/publication1100-verified.json`: HTTPS com CA validada, manifesto publicado idêntico ao aprovado, download completo de 208.171.550 bytes com SHA-256 correto, launcher correto, API saudável, histórico presente, quatro serviços ativos sem erros de script nos logs e backup SQLite anterior à ativação.
- `work/signed-install-validation.json`: **13 verificações** de assinatura real, ZIP, extração dos três arquivos e reabertura de instalação. EXE extraído iniciou 180 quadros e saiu normalmente, com DLL carregada e arquivos intactos. O teste dentro do executável protegido não executou encode/decode; os testes do codec e da rede de voz são evidências separadas, preservando a proteção do runtime.
- `work/native-package-validation.json`: **83 verificações** da lista de arquivos, assinatura, corrupção e extração segura.
- `tests/release_deployment.py`: **20 testes isolados** de política, ocupação, saúde, ativação e rollback.
- Protocolos: Guerra 30 e BR 6. Todos os clientes precisam atualizar.
