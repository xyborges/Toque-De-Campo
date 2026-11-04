# Servidor Ubuntu — Toque de Campo 1.10.4, build 78

**Versão ativa em 29/10/2026: 1.10.4/build 78.** Mantém as correções do BR e a redução de trabalho dos personagens no Guerra; ordena as posições dos bots por ator/vida e os estados da operação por geração/relógio. Publicação confirmada em `work/war-state-release-deploy.log`. Cliente e autoridade usam o protocolo 33 do Guerra; atualizar pelo launcher antes de reconectar. Evidências e limites em [ATUALIZACAO-1.10.4.md](ATUALIZACAO-1.10.4.md) e [CORRECAO-LAG-GUERRA-2026-10-29.md](CORRECAO-LAG-GUERRA-2026-10-29.md). Os registros de versões anteriores abaixo são históricos.

Atualizado em 29/10/2026. **Versão 1.10.0 publicada e validada na VM Ubuntu.** Inclui o Battle Royale, acessórios modulares, mochila com ações por item, corpos saqueáveis e voz por proximidade, além das correções de construções da Ucrânia e de tráfego dos blindados controlados por bots. Detalhes e limites em [ATUALIZACAO-1.10.0.md](ATUALIZACAO-1.10.0.md). Os registros de versões anteriores abaixo são históricos.

**Correção atual: 1.10.1/build 72.** Corrige a entrada online do BR, a postura deitado, a troca de apresentação de armas e punhos e remoção de nós destacados na implantação, e acrescenta cobertura com LOD no Afegão. A saúde dos serviços da 1.10.0 não havia comprovado a entrada efetiva no BR; os bloqueios identificados e as validações estão em [ATUALIZACAO-1.10.1.md](ATUALIZACAO-1.10.1.md).

**Substitua o atualizador antigo pelo novo executável uma vez.** Esta versão acrescenta a biblioteca de voz ao pacote assinado; o launcher antigo não entende esse terceiro arquivo. Contas e preferências são preservadas.

Este documento substitui as instruções antigas de XAMPP, porta 8088 e hospedagem manual pelos jogadores.

## Baixar, atualizar e jogar

1. Acesse **[https://192.168.101.24/](https://192.168.101.24/)** e baixe `ToqueDeCampo.exe`.
2. Abra o launcher. Ele consulta o manifesto e baixa o jogo somente quando há atualização; na segunda abertura testada da 1.6.4 informou que nenhum download era necessário.
3. Para os modos online, crie uma conta ou entre com nome e senha. Nome: 3–24 caracteres (`a-z`, números e `_`); senha: 12–128 caracteres. A senha não é salva pelo jogo.
4. Em **Jogar**, selecione o modo e confirme a ação desejada. Selecionar o cartão ou abrir Jogar não inicia uma partida ao fundo.

| Modo | Entrada |
| --- | --- |
| Offline original | Iniciar treino no escritório ou Treino no deserto. |
| Naval | Ver salas, entrar/criar e aguardar o dono iniciar. Mínimo de dois e máximo de seis jogadores. |
| PvP Deserto | Entrar no PvP central. Movimento/combate aguardam enquanto houver menos de dois jogadores. |
| Guerra online | Guerra → Conectar online → equipe, classe, equipamento e implantação. Até seis integrantes por equipe; bots completam as vagas e uma pessoa pode iniciar. |
| Guerra offline | Guerra → Treino offline · Bots. Dezoito participantes por padrão, sem sala/ENet ou recompensa global. |
| Battle Royale | Pareamento de 30 segundos, até doze participantes com bots. Partida iniciada fecha a entrada; nova busca recebe outro grupo. |

Não é necessário digitar IP/porta nem executar um BAT de servidor nos PCs dos jogadores. O endereço da VM é privado: fora da rede, é preciso VPN/rota até `192.168.101.24`. Os testes centrais comprovam o acesso deste ambiente à VM; não medem acesso pela internet pública.

Na cópia de desenvolvimento, `JOGAR-GUERRA-OFFLINE.bat` ou o argumento `--war-offline` abre diretamente a implantação local sem login.

## Infraestrutura publicada

| Componente | Local / serviço |
| --- | --- |
| Download, site e manifesto | Nginx, HTTP 80, `/var/www/toque-de-campo` |
| Contas e ranking | HTTPS 443, PHP 8.3-FPM + SQLite, `/accounts/api.php` |
| Dados privados de contas | `/var/lib/toque-de-campo/accounts` |
| Partidas navais | `toque-naval.service`, ENet UDP 3012; até oito salas de seis |
| PvP Deserto | `toque-pvp.service`, ENet UDP 3010; sessão central de seis |
| Guerra | `toque-war.service`, ENet UDP 3014; operação central de doze |
| Battle Royale | `toque-br.service`, encaminhador DTLS UDP 3016 e duas salas em UDP 3020–3021 |
| Build Linux ativo | `/opt/toque-de-campo/current` → `/opt/toque-de-campo/releases/build-78` |
| Dados/status/logs das autoridades | `/var/lib/toque-de-campo/game` |
| Backup diário | `toque-backup.timer`, `/var/backups/toque-de-campo` |

As portas são configuração interna, não parte do fluxo do jogador. Os serviços são geridos por systemd e iniciam com o Ubuntu. O treino Guerra offline mantém sua autoridade somente no processo local; não depende desses serviços.

## Persistência, segurança e atualização

- Saldo inteiro, frota comprada, navio selecionado, aparência e proporções são carregados da conta central. Contas novas começam com zero moedas e navio leve gratuito; dados anteriores são preservados.
- Preços/recompensas são definidos pelo servidor. Abate naval válido rende 100 moedas; infantaria/Guerra, 30. Eventos duplicados não geram crédito repetido. Treino Guerra offline não envia moedas nem estatísticas ao ranking global.
- O ranking exibe estatísticas persistentes, com cache de uma hora. Mortes online por ambiente/suicídio também são registradas pela autoridade, sem criar abates nem moedas. Um evento por vida deduplica morte e recompensa em qualquer ordem de chegada. NPCs e treino offline não alimentam esse total. O cache pode mostrar a fotografia anterior até expirar; o placar da partida é atualizado pelos eventos da própria partida.
- Login e contas exigem HTTPS validado pela CA privada embutida no cliente. Senhas usam Argon2id; sessões opacas, limites de tentativa, consultas preparadas e prova da chave do dispositivo protegem as operações.
- `match_register`, `reward`, `match_wallet` e `match_death` aceitam somente a credencial Service dos servidores, nos três modos. A credencial de serviço não concede ações privadas de uma conta. Testes de autorização contra PHP/SQLite isolados cobrem os quatro caminhos; a verificação central é registrada nos relatórios de ranking da versão publicada.
- SQLite, chaves e tokens ficam fora do diretório web. Backups incluem banco e chaves, com retenção de quatorze dias; a publicação cria snapshot antes de ativar o build. Não substituir o banco atual por um backup antigo ao atualizar.
- O download HTTP é verificado por manifesto RSA/SHA-256 assinado e hashes do ZIP/arquivos. O EXE inicial não tem certificado Authenticode. A chave privada de assinatura permanece local em `distribution/private/release-private.pem`; não deve ser distribuída.
- O publicador gera Windows, launcher e servidor Linux, envia por SSH com chave e host conhecido, verifica assinatura/hashes e ativa os arquivos de forma transacional. O manifesto público é atualizado ao final. Partidas ocupadas adiam a publicação; os três serviços entram na política de verificação e rollback.

## Evidências da 1.6.4

- Publicação: `work/release164-publication.log`, `DEPLOYED build=30 version=1.6.4`.
- Download real/instalação/segunda abertura sem download: `work/release164-distribution.log`, versão 1.6.4/build 30. Pacote offline exportado: quatro verificações em `work/war-offline-pack-164.log`.
- Morte por granada e respawn configurado no M, usando duas contas reais no Ubuntu: 19 verificações, pavio 5,021 s e respawn 4,050 s. Exatamente uma morte persistida, sem moedas ou abate. `work/release164-central-respawn.log`.
- Tripulação central: 33 verificações com três contas reais, `work/release164-central-passengers.log`.
- PvP Deserto e Naval: ambos com dois clientes autenticados, sem falhas. Logs `work/release164-central-pvp.log` e `work/release164-central-naval.log`.
- API/ranking central: 11 verificações, incluindo recusa HTTP 403 das quatro ações de autoridade para conta comum. `work/release164-central-ranking.log`.
- Fogo amigo: 19 verificações nativas e 16 com servidor/três clientes ENet. Pontuação, morte e avisos privados confirmados; `work/war-friendly-fire.stdout.log` e `work/release164-friendly-network.log`.
- Resumo completo da pós-publicação: `tests/release164-postpublication.json`, todas as seis etapas aprovadas.
- Protocolo Guerra: revisão 4. Todos os clientes precisam atualizar antes de entrar juntos.

## Histórico de validação da 1.6.3

- Publicação: `work/release163-publication.log`, `DEPLOYED build=29 version=1.6.3`.
- Download real, instalação/segunda abertura, assinatura, recursos e boot: `work/release163-distribution.log` e `tests/ubuntu-distribution-results.json`.
- Guerra central com duas contas reais: 17 verificações, `work/release163-central-war.log`.
- Pacote offline exportado: quatro verificações, `work/war-offline-pack-163.log`.
- Ópticas: 49 verificações nativas; respawn/câmera: 28 locais e 18 ENet; objetivos: 19; equipamentos offline: 34; áudio remoto real: 198. API isolada: 153; publicador/rollback: 14. Demais baterias e limites em `ATUALIZACAO-1.6.3.md`.
- Protocolo Guerra: revisão 3. Todos os clientes precisam atualizar antes de entrar juntos.
- Doze clientes: 59,20 FPS médios / 1% low 33,61. Isso não comprova 60 FPS estáveis; bancada e picos em `GUERRA-DESEMPENHO.md`.

## Histórico de validação da 1.6.1

- Publicação: `work/release161-publication.log` confirma `DEPLOYED build=27 version=1.6.1`.
- Tripulação contra o serviço central, com três contas reais: 33 verificações aprovadas, sem token Service ou autoridade de teste. Inclui direção/disparo, observação independente, recusa de RPCs indevidos, promoção e saída segura. Evidência: `work/release161-central-passengers.log`.
- Download, instalação real, segunda abertura sem download, assets e inicialização normal: aprovados em `work/release161-distribution.log` e `tests/ubuntu-distribution-results.json`, versão 1.6.1/build 27.
- Regressões locais: 91 assentos, 41 respawn, 79 sistemas de Guerra, 34 locomoção nativa, 18 locomoção ENet, 24 passageiros ENet, 18 rede anterior e 34 equipamentos offline. Evidências em [ATUALIZACAO-1.6.1.md](ATUALIZACAO-1.6.1.md).
- Protocolo de assentos de Guerra: revisão 2. Todos os clientes devem atualizar antes de entrar juntos.

## Histórico de validação da 1.6.0

- Publicação: `work/release160-publication.log` contém `DEPLOYED build=26 version=1.6.0`.
- Distribuição real: `tests/ubuntu-distribution-results.json` confirma TLS, caminhos privados protegidos, download idêntico, instalação pelo launcher, ausência de download repetido e inicialização do pacote.
- Guerra central: 17 verificações com dois clientes, em `work/release160-ubuntu-war.log`.
- Naval e PvP Deserto centrais: regressões aprovadas em `work/release160-ubuntu-naval.log` e `work/release160-ubuntu-pvp.log`, incluindo conta e disparos replicados.
- Ranking na API real: dez verificações, incluindo cache e recusas HTTP 403 às três ações de servidor; `tests/ubuntu-ranking-results.json`.
- Guerra offline: 42 verificações de operação, 34 de equipamentos repetidas com sucesso e quatro de entrada pelo pacote exportado. Não são medições de FPS.
- Modelos/LOD: 109 verificações e vistas nativas; scoreboard: 54; HUD: 25; estatísticas: 34. Relação completa em [ATUALIZACAO-1.6.0.md](ATUALIZACAO-1.6.0.md).

Na medição local atual da 1.6.1, doze clientes e um renderizando em 1080p na GTX 1650, a média foi 59,19 FPS e o 1% low 40,12. A medição offline de navegação com onze bots teve 60,00 FPS médios/1% low 54,11, mas registrou zero tiros. **Não comprova 60 FPS estáveis nem desempenho de combate offline intenso.** Consulte [GUERRA-DESEMPENHO.md](GUERRA-DESEMPENHO.md).

## Publicar uma versão futura

Atualize `distribution/release-notes.json` com versão, data, título, resumo e mudanças efetivamente validadas. O mesmo conteúdo alimenta site e manifesto/launcher.

Quando a próxima versão estiver concluída e aprovada pelos testes, execute, por exemplo:

```powershell
python distribution/ubuntu/publish_ubuntu.py --version X.Y.Z
```

Substitua `X.Y.Z` pela próxima versão validada, ou use `PUBLICAR-ATUALIZACAO.bat --version X.Y.Z`. Informe a versão explicitamente. `--prepare-only` prepara sem ativar; `--deploy-only` envia a versão já preparada. O número de build aumenta automaticamente. O helper root aceita somente os artefatos assinados dentro da política de publicação.

Antes de enviar qualquer byte, o publicador roda `distribution/ubuntu/preflight.py`: ele consulta o manifesto no ar e o diretório `/opt/toque-de-campo/releases/build-N` na VM e recusa cedo, com mensagem acionável, o build que não aumenta ou um diretório antigo de mesmo número com conteúdo diferente. Um release idêntico já presente continua permitido, como o helper exige para repetir o envio.

Se a ativação falhar depois de criar `/opt/toque-de-campo/releases/build-N`, esse diretório permanece e bloqueia um novo prepare com o mesmo número. Remova-o como root (`sudo rm -rf /opt/toque-de-campo/releases/build-N`) ou publique com o build seguinte. O build 80 da 1.10.6 ficou nesse estado e deve ser removido quando houver acesso root à VM; a 1.10.6 foi publicada como build 81.

**Fila seguinte:** concluir as lacunas auditadas do plano de áudio, ranking e HUD sem reescrever os sistemas corretos. Consulte [REVISAO-AUDIO-RANKING-HUD.md](REVISAO-AUDIO-RANKING-HUD.md).


Na versão publicada, Guarani/BMP-2 transportam um operador e até cinco passageiros; Abrams/T-90, um operador e um passageiro. Assentos, promoção, saída segura, morte dos embarcados e respawn de 60 segundos são tratados pela autoridade da partida.
