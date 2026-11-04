# Proteções da versão 1.8.2

## Conexões

Guerra, Deserto e Naval usam ENet sobre DTLS. O cliente exige a autoridade pública do jogo embarcada no pacote e verifica o IP/nome do servidor. O servidor mantém a chave privada fora dos arquivos distribuídos. Não existe fallback para ENet sem criptografia. Contas e atualizações usam HTTPS com verificação explícita da autoridade da rede privada.

O certificado do transporte de jogo é separado do certificado do site/contas. Sua chave privada é legível pelo serviço do jogo, mas a chave da autoridade é exclusiva de root. Certificados de QA só podem ser selecionados no editor ou em exportações QA.

No Ubuntu, a tabela nftables `toque_game_guard` limita excesso de datagramas nas três portas do jogo. Ela não substitui o firewall existente e não modifica SSH ou HTTP(S). Isso limita abuso simples; não protege a capacidade do enlace contra DDoS volumétrico.

## Regras no servidor

As regras existentes de vida, cadência, munição, equipamento, veículo, respawn e danos continuam na autoridade da partida. Foram acrescentados limites de frequência de RPCs e validação de movimento por tempo decorrido, sequência crescente e vida atual. Uma enxurrada de mensagens não acumula tolerância extra de deslocamento. Registros são apagados na desconexão.

Essas medidas não equivalem a um anticheat completo. Uma máquina controlada pelo jogador continua podendo analisar a memória ou tentar modificar o próprio programa.

## Arquivos e atualizações

O jogo Windows e o atualizador usam um runtime próprio Godot 4.7.2 com a chave de criptografia do PCK. Tanto o diretório do pacote quanto seu conteúdo são criptografados. Scripts externos e substituição de caminhos/pacotes pela linha de comando ficam desabilitados no runtime publicado. A configuração externa de substituição do projeto também fica desabilitada.

O atualizador verifica assinatura RSA do manifesto, versão, tamanho e SHA-256 do arquivo e dos dois arquivos instalados. A instalação usa uma lista fechada de nomes, e os arquivos voltam a ser verificados antes de iniciar o jogo. O atualizador exige HTTPS e recusa redirecionamentos.

A assinatura de atualização é própria do jogo. **Não é uma assinatura Authenticode do executável**, porque não existe certificado de publicador Windows contratado. A criptografia dificulta extração casual, mas não torna extração ou engenharia reversa impossíveis: o cliente precisa decifrar recursos para usá-los.

O runtime Linux e o pacote do servidor ficam apenas na VM. O pacote Linux não precisa da proteção de distribuição Windows e não deve ser colocado na pasta pública do site.

## Operação

- Baixar o novo atualizador uma vez: o anterior utilizava HTTP e não acompanha essa troca para HTTPS.
- O jogo/atualizador confiam diretamente na autoridade incluída. O navegador dos amigos precisa confiar na autoridade privada para acessar o site sem alerta. Não desabilitar validação de certificados para contornar isso.
- Guardar com backup restrito a chave de atualização, a chave do PCK e as autoridades/certificados da VM. Nenhuma chave privada deve ir para o site, o manifesto, o ZIP ou logs.
- A receita do runtime está em `tools/build_protected_runtime.sh`. O publicador recusa exportar se a chave ou o runtime protegido estiverem ausentes.
- Todos os participantes precisam atualizar, pois os protocolos das partidas foram alterados.

## Medição de custo do DTLS

Teste local com 12 clientes ENet reais e um servidor no mesmo processo, sem renderização. Cada cliente enviou 20 entradas por segundo e recebeu 60 snapshots de 900 bytes por segundo. Foram duas amostras com DTLS e duas sem, com aquecimento e oito segundos de medição por amostra.

| Medida média | ENet | ENet + DTLS |
|---|---:|---:|
| RTT local | 7,08 ms | 7,16 ms |
| Trabalho de rede no conjunto de servidor + 12 clientes | 28,24 ms/s | 34,58 ms/s |
| Conexão dos 12 clientes | 94,6 ms | 612,5 ms |

Diferença média de RTT: aproximadamente 0,07 ms (0,08 ms após arredondar as médias). Trabalho adicional de rede: 6,33 ms por segundo para o conjunto de processos simulados. As medições incluem scripts, ENet, criptografia e polling. Não são um benchmark de FPS, não isolam apenas a cifra e não medem a VPN ou a rede dos amigos. A negociação inicial ocorre ao conectar, não a cada tiro.

Dados brutos: `work/security182/dtls-benchmark.json`. Teste reproduzível: `tests/security182_benchmark.gd`.

## Validação

- Dois clientes Guerra por DTLS: morte real, espera de oito segundos, respawn e bloqueio das ações de morto.
- Deserto por DTLS: fluxo de implantação e combate.
- Naval por DTLS com perda/delay: disparos, dano, destruição, respawn, mudança de dono, entrada tardia e reconexão.
- Proxy UDP: mensagens legítimas chegam cifradas; certificado não confiável e cliente sem DTLS são recusados; reconexão legítima continua disponível.
- Guardas: rajadas de RPC, sequência repetida, movimento e limpeza na desconexão.
- Windows publicado: o runtime próprio abre o PCK; Godot padrão não consegue abrir seu diretório criptografado; substituições externas não executam.
- Atualizador publicado: instalação via HTTPS e recusa de HTTP.

Publicado no Ubuntu como **1.8.2, build 51**. O manifesto remoto e os arquivos baixados foram comparados com a publicação local; o atualizador real instalou a versão por HTTPS e a segunda abertura não baixou novamente. Guerra, Deserto, Naval, nginx e a proteção UDP ficaram ativos após a publicação. O teste de Guerra com duas contas mediu respawn em 8,08 segundos; o Deserto confirmou tiro e granada replicados; o Naval confirmou salas, entrada por código, disparos e continuidade após a saída do criador. O teste Naval de publicação foi headless e não mede áudio.

Os relatórios ficam em `work/security182/`. O certificado público do site está disponível em `/accounts-ca.crt`. SHA-256 do arquivo público conferido localmente: `AA8BD657E2499982FD5ED8E05A9BFA656E10E5269ED5EF88F277EC2924B87824`. Esse certificado serve para estabelecer confiança na rede privada; não é um certificado de assinatura Windows.
