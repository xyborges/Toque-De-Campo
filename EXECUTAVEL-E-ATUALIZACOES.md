> **Configuração anterior.** A partir de 22/10/2026, downloads, contas e partidas usam a VM Ubuntu `192.168.101.24`. Consulte [SERVIDOR-UBUNTU.md](SERVIDOR-UBUNTU.md) para a configuração atual. Não use os endereços/portas antigos abaixo para jogar.

# Executável Windows e atualizações

Servidor padrão: **192.168.101.227** (este PC, rede local).

## Entregar aos amigos

1. Abra `HOSPEDAR-ATUALIZACOES.bat` e mantenha a janela aberta. Se o servidor já estiver aberto, o BAT avisa e não cria outro.
2. Eles acessam **http://192.168.101.227:8088** e baixam `ToqueDeCampo.exe`.
3. Ao abrir, o launcher verifica a publicação, instala o jogo na pasta de dados do usuário e inicia o jogo. Não exige Godot ou Python no computador dos amigos.
4. Você abre o jogo e hospeda uma sala; eles entram pelo IP já preenchido. As atualizações usam **TCP 8088** e a partida usa **UDP 3010**.

O executável a distribuir fica em `distribution/published/ToqueDeCampo.exe`. É um launcher portátil; não é um instalador com assistente/desinstalador.

## Publicar mudanças

Depois de editar o jogo, execute `PUBLICAR-ATUALIZACAO.bat`. Ele exporta o jogo, aumenta o número de build e publica o pacote completo antes de trocar o manifesto. O servidor não precisa reiniciar. Um nome de versão opcional pode ser passado pelo terminal:

```powershell
python distribution/publish.py --version 1.1.0
```

Sem argumento, o nome é `1.0.N`. O número interno sempre aumenta. Os amigos precisam fechar e abrir o launcher para atualizar; uma partida em execução não é alterada. Não publique modificações de protocolo enquanto jogadores usam uma versão anterior: atualizem juntos.

## Regras do atualizador

- Consulta um manifesto pequeno a cada abertura. Se a versão e o conteúdo já estão instalados, não baixa o ZIP novamente.
- Na primeira execução, baixa o pacote completo. Cada nova versão também baixa um pacote completo, sem atualização incremental.
- Confere a assinatura RSA do manifesto e SHA-256/tamanho do pacote e de cada arquivo antes de ativar a versão.
- Aceita apenas os dois arquivos esperados, sem caminhos arbitrários do ZIP.
- Downloads incompletos, assinatura inválida ou falha de instalação não trocam a versão instalada.
- Se o servidor estiver desligado, oferece jogar a versão instalada. Sem instalação anterior, é necessário acessar o servidor para o primeiro download.
- Mantém versões anteriores em disco para não sobrescrever arquivos abertos; não faz limpeza automática nesta primeira implementação.
- Arquivos instalados ficam em `%APPDATA%/Godot/app_userdata/Toque de Campo Launcher`. Se essa pasta não permitir gravação, usa `ToqueDeCampo-data` ao lado do executável e mantém essa escolha nas próximas aberturas. O perfil do jogo continua na pasta de usuário própria do jogo; não é substituído pelos pacotes.
- O launcher atualiza o jogo, não substitui a si próprio. Se o launcher mudar, distribua novamente o executável com `--launcher`.

## Hospedagem

Esse IP privado é acessível no mesmo Wi-Fi/rede ou por uma VPN configurada para alcançar a rede. Para amigos na internet, será necessário configurar endereço acessível, roteamento e servidor; apenas enviar esse IP não basta.

Permita o servidor de atualizações no Firewall do Windows em **redes privadas** se aparecer o aviso. A partida também precisa de UDP 3010 permitido. Não é necessário XAMPP. O servidor de arquivos é separado da sala do jogo: mantê-lo aberto não cria uma partida.

Se o IP deste PC mudar, será preciso reservar o endereço no roteador ou alterar a configuração e redistribuir o launcher. Nenhuma regra de firewall ou configuração do roteador é alterada automaticamente.

## Publicação e chaves

Guarde backup de `distribution/private/release-private.pem` em local privado. Não envie essa pasta aos amigos. A chave pública fica embutida no launcher; trocar a chave privada sem redistribuir o launcher torna futuras publicações incompatíveis. O servidor HTTP só expõe os arquivos da pasta `published`, nunca as chaves ou o código-fonte.

A assinatura verifica os pacotes de atualização; o executável Windows inicial não tem certificado Authenticode. O Windows pode indicar editor desconhecido. Distribua o executável inicial por um meio de confiança.

Fontes: [exportação Windows](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html), [assinaturas Crypto](https://docs.godotengine.org/en/stable/classes/class_crypto.html).

## Validação desta entrega

- Executável Windows real: instalação inicial, abertura sem baixar novamente, servidor fora do ar, assinatura inválida, pacote corrompido, atualização de versão e recusa de versão anterior.
- Servidor consultado pelo endereço real `192.168.101.227:8088`; instalação padrão e segunda abertura concluídas. A alternativa portátil foi usada devido às restrições de gravação deste ambiente.
- Jogo instalado abriu com renderização OpenGL na GTX 1650 e encerrou normalmente, sem erro de script. O ambiente impediu a criação do cache de shaders em `user://`; isso não impediu a abertura.
- Acessibilidade de outro computador e regras externas de firewall ainda dependem de validação na rede dos amigos. Não foram alteradas regras do Windows ou do roteador.
