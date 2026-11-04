# Battle Royale — partidas independentes

O servidor BR usa um encaminhador seguro na porta UDP 3016. Ele autentica a conta e a prova de posse da chave do dispositivo, reserva uma vaga e encaminha o jogador para uma partida aguardando participantes. A reserva só pode ser usada uma vez, pela conta correspondente, enquanto essa partida aceita entradas.

Cada partida executa em processo separado, com porta e pasta próprias. O serviço preparado para a máquina de 8 GB limita a duas partidas simultâneas; o código aceita `--br-max-rooms=1..16` para outras máquinas, mediante revisão do orçamento e da política de implantação. As portas disponíveis são UDP 3020–3035; a implantação atual usa somente 3020 e 3021. Os clientes não recebem acesso a um painel para criar processos sem limite. Quando todas as vagas/processos estão ocupados, a busca informa que é necessário tentar novamente.

A contagem de 30 segundos começa na primeira entrada autenticada. Entradas posteriores não reiniciam a contagem. Depois do fechamento da fila, outro grupo recebe uma partida diferente. Quem desiste antes de receber o encaminhamento libera a reserva; reservas entregues vencem após 45 segundos. Uma sala que ainda carrega tem até 90 segundos para ficar pronta, e uma sala vazia é recolhida. A partida também encerra quando todos os humanos saem.

O encaminhador apenas autentica e aloca. A partida mantém física, zona, loot, combate e voz no seu próprio servidor autoritativo. O servidor de contas continua responsável pelas credenciais; chaves privadas de contas não entram no pacote do jogo.

O serviço local preparado em `distribution/ubuntu/toque-br.service` inicia `--br-server`. Os processos filhos recebem `--br-room`, identificador, porta, pasta e os caminhos de TLS/credencial de serviço já configurados. O serviço utiliza `KillMode=control-group`, encerrando também os filhos quando o serviço para. O firewall da implantação precisa permitir UDP 3016 e o subconjunto utilizado de 3020–3035. Este arquivo não instala, publica, abre portas nem reinicia serviços por si só.

Configuração de serviço preparada: duas partidas, limite de memória total de 4 GB para encaminhador e filhos e 512 tarefas. Os outros serviços e o sistema compartilham os 8 GB físicos. Esse limite não comprova capacidade de duas partidas com fluidez; o sistema deve recusar novas buscas quando o limite de processos estiver ocupado.

## Publicação e proteção operacional

`distribution/ubuntu/publish_ubuntu.py` inclui a unidade BR como artefato assinado, além do jogo, servidor, site e API. O helper privilegiado deve ser atualizado previamente para a política correspondente: versões anteriores recusam o artefato extra. A validação aceita somente as diretivas exatas da unidade, com usuário sem privilégios, `KillMode=control-group`, duas partidas e memória de 4 GB.

O encaminhador escreve `br-broker-status.json` com `connections` representando os humanos nas partidas e buscas, e `updated` em tempo Unix. A ativação exige heartbeat novo e que o PID principal do serviço possua a porta UDP 3016. Antes de reiniciar, o publicador recusa serviços ocupados e consulta também os status dos processos de partida; um broker desconectado dos jogadores não indica uma partida vazia.

A transação preserva o executável anterior, API, downloads, unidades e estado habilitado dos serviços. Uma falha na saúde do BR restaura esses elementos e reinicia os serviços anteriores. O manifesto público continua sendo trocado por último. O backup SQLite permanece anterior à ativação; credenciais e chaves não fazem parte dos artefatos públicos.

Preparar localmente, sem ativar na VM:

```powershell
python distribution/ubuntu/publish_ubuntu.py --version X.Y.Z --prepare-only
```

Depois de revisar a versão preparada e autorizar a publicação, `--deploy-only` envia e ativa exatamente seus artefatos assinados, sem reconstruí-los. A instalação inicial do helper atualizado e a abertura controlada de UDP 3016/3020/3021 são uma migração de infraestrutura separada; os scripts de exportação não executam essa migração automaticamente.

Os testes isolados em `tests/release_deployment.py` verificam assinatura de artefatos permitidos, política das unidades, jogadores ativos, heartbeat/socket, primeira ativação e rollback de instalações BR existentes. Não acessam systemd nem a VM.
