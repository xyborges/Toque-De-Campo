# Adições de 28/10 — voz, terreno e Battle Royale

Complementa `AFEGANISTAO-BR-PENDENTE.md` e o anexo original. Registro histórico dos requisitos e da avaliação inicial de 28/10. Voz, navegação e BR foram integrados e validados posteriormente; estado final em `BATTLE-ROYALE-CONCLUSAO.md` (29/10). Não publicar sem aprovação. Não incluir a Nova Grama na atualização atual.

## Voz por proximidade

- X, push-to-talk, somente vivos. Resolver o atalho X antigo sem acionar dois sistemas. Um capturador local, nenhuma captura por jogador remoto; indicador, volume, desligar chat, silenciar jogador e dispositivo de entrada.
- Opus mono em 16–24 kHz, 16–24 kbps, quadros de 20 ms. Sem cancelamento de eco, supressão de ruído, AGC automática ou serviços externos na primeira versão. PCM sem compressão só como último recurso fundamentado.
- Comparar AudioEffectCapture em barramento silenciado com entrada direta do AudioServer. O usuário enviou posteriormente a ressalva de atraso acumulado no barramento; preferir entrada direta se o teste real confirmar menor latência e ciclo de ativação correto. Drenar/descartar dados antigos ao parar a fala; não transmitir áudio acumulado após pausa.
- Transporte próprio no ENet/DTLS existente, canal dedicado **não confiável**, pacotes pequenos. Não copiar cegamente o RPC do exemplo do addon. Servidor obtém o falante pelo remetente autenticado, acrescenta ID/vida/sequência e só retransmite para receptores vivos no raio + margem, respeitando mute e limite de taxa/tamanho. Nunca aceitar ID de falante fornecido pelo cliente. Servidor não decodifica/mistura e não depende de biblioteca Opus ou dispositivo de áudio.
- Cliente: decoder e jitter de 40–60 ms por falante, até 4–6 vozes mais próximas, AudioStreamGenerator/AudioStreamPlayer3D no personagem. 10 m claros, queda até 40 m; configurações dentro de limites para manter o filtro da autoridade. O raio usa o corpo, não câmera solta/drone. Morte, saída de sala e troca de personagem eliminam fala, buffers e referências.
- Reutilizar a sincronização de preferências por conta para opções numéricas. O nome do dispositivo é específico de cada computador; não supor que um dispositivo remoto exista localmente. Mute precisa de identidade estável de conta, sem confiar só em IDs de conexão recicláveis.
- Testes: 2 e 4 clientes, perda/reordenação/atraso, fala durante morte, entrada tardia e limpeza. Medir fila/underflow/overflow, não apenas bytes enviados. Teste de codec sintético não substitui microfone ou escuta humana.

### Comparação inicial realmente feita

| Candidato | Evidência consultada | Situação local |
|---|---|---|
| [Godotopus](https://github.com/Mako-Mako-Games/godotopus) | MIT. O **main atual** já declara API/mínimo 4.7, VoiceSender/Receiver/Transport e canal não confiável dedicado; não coincide com a revisão antiga descrita na conversa. Continua avisando que está em desenvolvimento. | A release **v0.0.2 sem DNN** tem API antiga (GodotOpusEncoder/Decoder, VoiceTransmitter) e manifest mínimo 4.2. Seu ZIP de 4.279.554 bytes foi conferido pelo SHA-256 da release: `069d54a3d128fcf3b2d4b647545866cbdc298f14ea846b6eb87799c22b4cb7db`. O binário Windows debug carregou em 4.7.2 e passou codificação/decodificação sintética. Não confundir com teste do main ou da exportação release. |
| [TwoVoip](https://github.com/goatchurchprime/two-voip-godot-4/releases/tag/v6.6) | MIT. A release informa builds Windows/Linux e ensaios na API 4.6; a documentação fornece interface de pacotes/encoder e controle de jitter. O pacote reúne diversas plataformas/configurações; seus ~119,7 MB não são o custo do cliente Windows isolado. | Metadados/README/release consultados. DLL **ainda não testada localmente em 4.7.2**. Não declarar compatibilidade confirmada nem instalar no jogo até esse ensaio. |

Resultados Godotopus: 100 quadros sintéticos por taxa, mono/20 ms. Em 16 kHz: ~19,64 kbps de payload, p99 de codificação 391 µs e de decodificação 60 µs. Em 24 kHz: ~19,69 kbps, p99 436/51 µs. São uma sondagem curta, não orçamento de CPU em combate nem latência ponta a ponta. DTX entrou após silêncio; FEC e PLC retornaram os tamanhos esperados. **DRED indisponível** no binário sem DNN. Não habilitar DRED só porque há método exposto.

O laboratório inicial ficou em `work/voice-lab/`, ignorado pelo projeto principal com `.gdignore`; nele nenhum microfone foi ligado. A implementação posterior fixou a release v0.0.2 em `native/voice/`, com licenças, DLLs debug/release testadas, transporte próprio e exclusão do pacote de servidor. Ensaios posteriores de dispositivo conservaram apenas contagens, sem gravar ou transmitir fala. Ver `VOZ-PROXIMIDADE-CLIENTE.md` para os resultados atuais e a distinção entre testes sintéticos e conversa humana.

## Terreno e fundo

- Avaliar Terrain3D versus setores atuais em projeto isolado, na mesma 4.7.2/Compatibility/Jolt. [Plataformas oficiais](https://terrain3d.readthedocs.io/en/stable/docs/platforms.html) declaram Compatibility desde Terrain3D 1.0/Godot 4.4; isso não prova que uma DLL específica opere corretamente na nossa versão. [Releases](https://github.com/TokisanGames/Terrain3D/releases) e licença MIT devem ser fixadas ao testar.
- Heightmap com LOD; SRTM/ASTER apenas como forma-base, com licença/proveniência registradas. Comprimir verticalmente, rotas com inclinações máximas de aproximadamente 40–45° e transições dirigíveis. Não transportar montanhas reais de 2 km de altura diretamente ao mapa.
- Anel distante de baixa resolução, montanhas simples/panorama e névoa de profundidade/altura, sem colisão além da borda jogável. Não criar oceano em volta do Afeganistão.
- Vegetação por bioma pintável e MultiMesh/células, densidade adequada ao clima seco e cobertura justa entre presets. Reusar arquitetura sem reativar a Nova Grama cancelada.
- Navmesh pré-calculado para bots e candidatos de spawn: inclinação, água, distância entre participantes, conectividade. Zona final em região acessível do mesmo componente. O servidor não pode depender de uma câmera gráfica para manter colisões das regiões onde há jogadores/bots.
- Hoje muitas consultas usam WarTerrain estático diretamente. Introduzir consulta por cenário com migração controlada; não trocar o terreno da Ucrânia globalmente para fazer o mapa novo. Validar blindados, altura do servidor e colisões antes de adotar plugin.

## Battle Royale

- Zona autoritativa: centro/raios atual e alvo, início e duração das fases replicados; clientes interpolam pelo tempo do servidor. Dano fora calculado no servidor. Anel visual perto da borda com fade e tonalidade fora; evitar cilindro translúcido cobrindo o mapa inteiro.
- Loot como dados no servidor: ID, tipo, posição, quantidade e disponibilidade. Grade espacial; cliente instancia só a 60–80 m e libera distantes. Coleta atômica, distância, vida, capacidade e obstáculos validados; dois jogadores não pegam o mesmo item. Um contêiner por corpo.
- Tabela de loot como Resource editável, pesos por região/tipo, semente por rodada e recursos mínimos próximos dos spawns. Munição por calibre coerente com cada arma.
- Soco só no instante ativo da animação, teste curto de contato, limite de cadência e compensação de latência com limites, decididos na autoridade. Reusar o sistema de golpes sem conceder dano em área por mera proximidade.
- Estatísticas do servidor: dano, tiros, acertos, distância, itens e resultado no final. Ranking global separado por modo em etapa posterior.
- Permanecem as regras originais: individual inicial, sem veículos/paraquedas/respawn e início desarmado; espectador não transmite/recebe voz de vivos. Não modificar as regras do Guerra/Deserto existentes para acomodar BR.

Escolha registrada na implementação: preservada a tabela de fases do anexo, que soma 925 s (15 min 25 s), em vez da estimativa textual de 17 min.
