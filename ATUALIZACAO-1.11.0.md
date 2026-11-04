# 1.11.0 — Personagem, proteção e cenário (build 82)

03/11/2026. Preparada exclusivamente em `C:\Users\Joao Borges\Documents\campo-cartunesco-godot\campo-cartunesco-godot`. Publicação autorizada pelo usuário, priorizando verificações essenciais e deixando o benchmark longo pendente. O publicador confirmou `VERIFIED_READY build=82` e `DEPLOYED build=82 version=1.11.0` após verificar o build 81 vigente.

## Entregas

- Nova grama preparada no Guerra e Deserto, padrão Médio, sem a antiga simultaneamente. Pools fixos de 25 células próximas e 25 distantes; malhas compartilhadas e transição opaca pelo shader. Qualidade não altera colisões ou cobertura física.
- Distância de cenário 250/400/650/900 m, padrão 400 m; controles separados de vegetação e LOD. Lunetas e binóculos priorizam o setor estável dentro do limite escolhido, com atualização limitada por quadro e retenção ao mover a câmera.
- Personagem como fundo 3D da trincheira com névoa, personalização por hover e clique, painel lateral com as conexões atuais. Capacete do login corrigido. Uniforme do Guerra conserva a identidade do time.
- Equipamentos salvos por equipe/classe, aplicados na próxima implantação. Colete e capacete possuem proteção regional, peso, resistência, som de quebra e remoção. Autoridade replica vida e revisão para impedir restauração por mensagens antigas ou proteção acumulada. BR e Naval conservam suas regras.
- Objetivos do Guerra redistribuídos, ajustes físicos perto de E, motos e deslocamento dos bots, restauração da arma ao desembarcar. Identidade e dados preparados dos cinco mapas conferidos.

## Verificações concluídas

- Dados preparados dos mapas: 11.992.060 verificações, sem erros.
- Proteção: 27 verificações; rede com autoridade e dois clientes ENet no mesmo processo: 13; BR: 60.
- Menu e login: 35; ópticas e transportes: 55; controlador de cenário: 19.
- Teste gráfico real de 20 segundos: 27 verificações, GTX 1650 em 1920 × 1080 com 18 participantes, movimento e mudanças rápidas de câmera, luneta, binóculo e presets. Pools e colisões permaneceram estáveis.
- Windows e Linux exportados sem erros nos logs. Instalação assinada local: 13 verificações, hashes e assinatura válidos; cliente protegido inicializou e encerrou com código zero, carregando a DLL correta.
- Pós-publicação: o script `work/verify_release1110.py` verifica manifesto público idêntico, download do launcher, instalação real, segunda execução sem download e quatro serviços ativos. O resultado fica em `work/release1110-verification/results.json`; consultar esse arquivo para a confirmação final.

## Limites conhecidos

O teste gráfico curto ainda registrou p99 de 37,13 ms, pior quadro de 67,187 ms e 71 quadros acima de 33 ms em 20 segundos. Isso não satisfaz a aprovação de desempenho originalmente proposta. Não foi executada a bateria A/A e cinco pares A/B, nem uma partida longa com três processos gráficos independentes. O microstutter continua em investigação; não é declarado eliminado. `grass_enabled` ativa a escolha solicitada pelo usuário; `grass_approved` permanece falso para registrar a ausência dessa aprovação formal.

## Pacote e rollback

- Pacote assinado: `releases/game-82-69931bdcc390.zip`, 250.799.183 bytes; SHA-256 `69931bdcc39069ef9f0a4b388b181659d50681e5c3b979a1f3385a72f1385584`.
- Download: https://192.168.101.24/ . O launcher existente consulta o manifesto assinado.
- Publicador oficial com hashes autenticados, SSH com chave de host fixada, recusa de salas ocupadas e rollback automático. Build anterior: 81/1.10.6, preservado em `/opt/toque-de-campo/releases/build-81`.
- Não misturar cliente 81 com servidor 82: mapas e protocolo de equipamentos precisam corresponder. Uma reversão deve retornar o release completo pelo procedimento do servidor, incluindo manifesto público; não desativar apenas a grama nem substituir arquivos isolados.

## Comandos utilizados

Executar na pasta do novo projeto:

```powershell
python distribution/ubuntu/publish_ubuntu.py --version 1.11.0 --prepare-only
python distribution/validate_signed_install.py --build 82
python distribution/ubuntu/publish_ubuntu.py --version 1.11.0 --deploy-only
python work/verify_release1110.py
```

O comando de preparação gera um novo número a cada execução; não repetir apenas para verificar o release já publicado. `--deploy-only` usa o estágio assinado existente.
