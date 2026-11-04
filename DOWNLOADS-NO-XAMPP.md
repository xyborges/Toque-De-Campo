> **Configuração anterior.** A partir de 22/10/2026, downloads, contas e partidas usam a VM Ubuntu `192.168.101.24`. Consulte [SERVIDOR-UBUNTU.md](SERVIDOR-UBUNTU.md) para a configuração atual. Não use os endereços/portas antigos abaixo para jogar.

# Downloads no XAMPP

A publicação foi configurada diretamente em `C:/xampp/htdocs/toque-de-campo`. Uma cópia preparada também fica em `distribution/xampp/toque-de-campo`.

Para instalar em outro XAMPP, copie a pasta inteira `distribution/xampp/toque-de-campo` para `C:/xampp/htdocs/toque-de-campo` (ou o `htdocs` da sua instalação).

```text
htdocs/toque-de-campo/
  index.html
  ToqueDeCampo.exe
  manifest.json
  .htaccess
  releases/
    game-1-....zip
    game-2-....zip
```

Inicie o **Apache** no XAMPP e abra **http://192.168.101.227/toque-de-campo/**. A configuração usa HTTP, porta 80 e esse nome exato de pasta. Se o Apache estiver em outra porta ou você mudar a pasta, será necessário alterar o endereço do launcher e reexportá-lo.

Este executável é a variante **XAMPP**, configurada para buscar o manifesto nesse endereço. O executável anterior buscava a porta 8088: os amigos devem baixar o novo executável da página uma vez para passar a utilizar o XAMPP. Os pacotes continuam assinados com a mesma chave.

Para publicar versões, execute `PUBLICAR-ATUALIZACAO.bat`. O caminho em `distribution/deploy-config.json` recebe a cópia automaticamente. Ao transferir manualmente para outro PC, copie novamente a pasta preparada para o `htdocs/toque-de-campo`. Copie primeiro o novo ZIP em `releases` e **por último** `manifest.json`, evitando anunciar um pacote ainda ausente no Apache. O Apache não exporta automaticamente suas alterações do Godot.

Não copie `distribution/private`, o projeto ou os perfis para o `htdocs`. Somente a pasta preparada acima é pública. A listagem de diretórios está desativada por `.htaccess`; o cabeçalho de cache do manifesto é aplicado quando o módulo Apache `headers` está disponível.

Se outro computador não acessar, permita o **Apache** no firewall na rede local e confirme que os dispositivos não estão em Wi-Fi de visitantes/isolamento de clientes. A regra anterior da porta 8088 é específica do servidor Python e não libera automaticamente o Apache na porta 80.

O XAMPP hospeda downloads e atualizações. O multiplayer Godot usa ENet/UDP e precisa do servidor do jogo; não roda dentro do Apache.
