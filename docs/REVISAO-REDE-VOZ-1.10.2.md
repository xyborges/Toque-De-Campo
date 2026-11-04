# Revisão de rede e voz — 1.10.2 (auditoria pré-publicação)

Registro histórico da preparação. A versão final foi publicada posteriormente como build 74; consulte `ATUALIZACAO-1.10.2.md` para a verificação da publicação.

## Produção: leitura em 29/10/2026

O servidor continuava na build 72. Nenhum serviço foi reiniciado ou alterado. A leitura SSH usou a chave conhecida e, para os arquivos restritos, a credencial DPAPI já existente somente na entrada padrão de uma consulta administrativa. Nenhuma credencial ou token foi impresso ou copiado para este relatório.

Evidências locais: `work/1102-production-readonly-audit.log` e `work/1102-production-br-room-audit.log`. O journal registrou falhas DTLS `-30464`/mbedtls `-0x7700` em algumas salas e consultas ENet a IDs ausentes. Esses registros não identificam o jogador nem comprovam crash do cliente. Inclusive uma sala de QA que concluiu a partida também registrou uma falha de handshake em seu histórico. Sem o log da máquina afetada, não se pode concluir que DTLS causou a saída do amigo.

A sala `70b3f706e42c706d4c41422553d05cde` terminou cancelada e sem humanos; o arquivo contém duas falhas TLS e consultas repetidas a IDs ausentes. Nenhum dump de falha ou mensagem de admissão do cliente está disponível nos logs antigos.

## Correções locais da revisão

- `scripts/network_peers.gd`: cache do ENetPacketPeer preenchido no sinal nativo de conexão; as consultas seguintes verificam estado/canais sem consultar novamente a tabela nativa por um ID que já desapareceu. Referências inativas são descartadas. Os callbacks usam WeakRef para não reter o transporte.
- `scripts/secure_transport.gd`: instala o cache antes da primeira consulta/poll do transporte DTLS. Certificados, validação, conexão segura e protocolos permanecem os mesmos.
- Os guards e métricas de `scripts/main.gd`, `network_broadcast.gd`, `network_diagnostics.gd`, `network_shutdown.gd`, do roteador BR, do naval e da voz agora usam esse cache. Além do intervalo entre a lista de SceneMultiplayer e a tabela ENet, a latência de ataques corpo a corpo também podia consultar um ID de bot como se fosse uma conexão real.
- `modes/battle_royale/voice/relay.gd`: remove conversões `bool(null)` de personagens sem a propriedade BR `br_bot`, que produziam erros repetidos no Guerra e no naval. Usa comparações explícitas.
- `scripts/voice/naval_adapter.gd`: a troca de sala de um mesmo jogador invalida a lista de nomes/identidades de voz, mesmo quando o conjunto global de contas não muda. A filtragem de áudio entre salas já existia; a correção cobre também a apresentação e os alvos de silenciamento.

O helper é para transportes instalados pelo GameSecureTransport. Fixtures que deliberadamente criam ENet cru devem chamar `GameNetworkPeers.watch(peer)` antes de fazer polling. Não há fallback que volte a fazer a consulta nativa insegura.

## Verificação

- `tests/network_peer_cache1102.gd`: **130 verificações passaram**, com oito conexões/saídas forçadas reais em loopback. O teste reproduziu a lista de SceneMultiplayer contendo um ID que o ENet já removeu e verificou consultas repetidas, canais insuficientes, ID inexistente, transporte fechado e liberação do cache, sem erros nativos. É ENet cru; DTLS é coberto pelas suítes de rede separadas.
- `tests/br_voice_lifecycle_validation.gd`: **13 verificações passaram**, com codec Opus sintético, fechamento, buffers e estado de sessão. Nenhuma captura real de microfone.
- O cenário de Guerra com 28 bots e dois clientes, repetido por outro agente após esta correção, deixou de produzir erros do relay. Um dos clientes ainda registrou aviso de buffer UDP cheio; isso requer avaliação da carga/fluxo do cenário e não é explicado por esse ajuste de consulta ENet.

A revisão dos bloqueios de sincronização não encontrou um novo bloqueio demonstrável além das mudanças em teste pelo agente principal. A confirmação completa de três clientes e as motos é registrada pelas suítes específicas do agente principal e do responsável pelas motos. Nenhuma publicação foi realizada nesta revisão.
