# Atualização 1.5.3 — granadas e feedback de combate

## Controles e regras

- No Arsenal, marque as armas adquiridas que deseja levar. Pelo menos uma permanece selecionada. A arma inicial deve pertencer à seleção.
- Granadas são opcionais no equipamento: duas por vida. Segure **G** para visualizar a trajetória; solte **G** para lançar. Morrer, abrir menu ou perder o foco cancela a preparação.
- A granada explode três segundos após o lançamento. Raio de seis metros, dano-base de 120 com redução linear pela distância. A explosão pode atingir o próprio lançador, sem gerar recompensa por suicídio.
- A cobertura é calculada no servidor: três consultas físicas entre a explosão e alturas do corpo. Uma parede que bloqueia todas as consultas impede o dano; exposição parcial reduz proporcionalmente o dano. Não há propagação artificial através de paredes.
- Origem na mão, velocidade herdada nos três eixos, gravidade, colisão esférica e quique são compartilhados pela previsão e pela simulação real. A guia aparece somente na preparação da granada; não foi adicionada às armas de fogo.

## Combate e apresentação

- Sniper: velocidade de 105,8 para 160 m/s, gravidade de 8,3385 para 12 m/s² e alcance de 300 m. Na mesma distância, a queda acumulada é aproximadamente 37% menor. Continua superior à queda de Glock e FAL. A luneta fecha ao morrer e não é alterada pela atualização visual de outro avatar.
- Som de passagem próxima ampliado de 2,8 para 6 m. Novo impacto sintetizado de terra, limitado por cadência e reproduzido na posição do impacto.
- Cada acerto produz um pulso na tela que desaparece em 0,34 s. Vida baixa não mantém a tela permanentemente escura. Mesmo componente reutilizado no Naval.
- Traçantes com cores por arma, emissão maior e espessura visual ajustada pela distância. O núcleo e o traçante seguem o mesmo projétil; não foi criada uma segunda munição.
- Números de dano em 3D acima dos alvos, visíveis somente para o atacante. Mostram a perda efetiva de vida, limitada à vida restante, com confirmação do servidor no multiplayer. Inclui NPCs, infantaria PVP e navios. Eventos repetidos não geram números duplicados. Rótulos respeitam profundidade e têm pool limitado a 48.
- PVP Deserto com menos de dois jogadores apresenta aviso central no tema existente. Movimento e combate aguardam outro participante.

## Causas corrigidas

1. **Carregador preso após saída do adversário:** o servidor rejeitava o disparo pela regra de dois jogadores antes de confirmar a sequência prevista pelo cliente. A sequência válida passa a ser reconhecida mesmo quando o disparo é recusado, e o inventário é sincronizado após a saída.
2. **Envio durante desconexão:** a lista de peers podia conter um transporte cujo canal já havia fechado. Inventário e broadcasts verificam estado e canais antes de enviar.
3. **Reconexão sob perda:** fechar imediatamente o ENet enviava uma saída sem manter a conexão para retransmissão. A interface agora separa o transporte antigo e permite que ele conclua o encerramento em segundo plano por até dois segundos. Uma nova sessão com ticket e prova criptográfica válidos pode substituir a sessão anterior da mesma conta.
4. **Sessões locais com relay desnecessário:** passam a usar a mesma comunicação exclusivamente por servidor já usada no serviço dedicado.
5. **Efeitos após sair:** temporizadores de clarão usam referências fracas. Granadas, guias, números e feedback pertencem ao mundo da partida e são descartados com ele.
6. **Granada atravessando chão em repouso:** a varredura não detectava uma sobreposição inicial. O contato inicial é resolvido antes de avançar a esfera.

## Arquivos principais

- `scripts/grenades.gd`, `scripts/main.gd`, `scripts/player.gd`: granadas, equipamento, autoridade e transições.
- `scripts/network_shutdown.gd`: encerramento do transporte separado da interface.
- `scripts/damage_numbers.gd`, `scripts/ui/damage_flash.gd`: componentes compartilhados.
- `scripts/ui/loadout_panel.gd`, HUD de infantaria: seleção e indicadores.
- `scripts/weapons.gd`, `scripts/tracer_style.gd`, `scripts/combat_feedback.gd`: balística, cores e áudio.
- `modes/naval/scripts/match.gd`, `network.gd`, `mode.gd`, `projectile_visual.gd`: dano confirmado e apresentação naval.
- `distribution/release-notes.json`: mesma fonte para novidades do site e do instalador.

## Validação

Os relatórios em `tests/` e logs `work/combat-153-*` registram os resultados. Os testes usam dados isolados; nenhuma conta humana foi usada para simular abates.

- Teste nativo renderizado: 48 verificações de balística, equipamento, morte mirando, flashes, dano, cobertura total/parcial e guia da granada.
- ENet com servidor e dois clientes reais: granada e explosão sincronizadas, dano confirmado, saída do adversário, espera, reconexão e recargas completas de FAL e sniper.
- Teste naval: 10 verificações de dano efetivo, escopo de sala/partida, deduplicação, rótulos somente do atacante e pulso na vítima.
- Login e menus no executável exportado: 44 verificações, incluindo sessão, saída da conta e múltiplas resoluções.
- Regressões: combate, armas brancas, ragdoll, física e lobby naval e feedback de combate.

O simulador de perda também foi revisado: cada endpoint de cliente usa um socket de encaminhamento próprio, preservando os pacotes pendentes da conexão antiga. As primeiras falhas e os logs de diagnóstico foram preservados; não foram apagados para apresentar apenas execuções aprovadas. A validação final rejeita erros de script e de transporte, além de conferir os resultados de jogabilidade.

Base técnica para o encerramento e o relay: [implementação oficial do ENetMultiplayerPeer](https://github.com/godotengine/godot/blob/master/modules/enet/enet_multiplayer_peer.cpp) e [SceneMultiplayer na documentação do Godot](https://docs.godotengine.org/en/stable/classes/class_scenemultiplayer.html#class-scenemultiplayer-property-server-relay).

## Limites da entrega

A cobertura usa três amostras físicas, não uma simulação volumétrica de pressão. A previsão considera o cenário no momento em que é calculada; um obstáculo móvel pode alterar um quique posterior. Os testes desta atualização não substituem o benchmark de 12 jogadores do Modo Guerra, que continua em desenvolvimento e desabilitado no menu público.

## Publicação

**Publicada em 23/10/2026: versão 1.5.3, build 23**, em http://192.168.101.24/.

- Ativação assinada na VM: `work/combat-153-deploy.log`, com `VERIFIED_READY build=23` e `DEPLOYED build=23 version=1.5.3`.
- Três execuções consecutivas com perda de 8% e atraso de 20–70 ms: `work/combat-153-loss-network-final-1.log`, `-2.log` e `-3.log`. Todos os processos terminaram com código zero, sem erros de script ou transporte.
- As 44 verificações de login e menus foram repetidas no executável final, sem falhas: `work/combat-153-final-login-native.log`.
- Dois executáveis nativos autenticados no Naval: `work/combat-153-central-naval.log`. Disparo, movimento, áudio remoto e continuidade após a saída do criador aprovados.
- Dois clientes autenticados no PVP Deserto: `work/combat-153-central-pvp.log`. Sem jogador fantasma do servidor, arma inicial correta e disparo confirmado nos dois clientes.
- Três processos na VM, incluindo duas sessões simultâneas da mesma conta: `work/combat-153-central-reconnect.log`. A sessão antiga foi encerrada e voltou ao menu; o observador permaneceu conectado com dois jogadores e sem avatar antigo; lançamento e explosão da granada foram recebidos por ambos, com consumo de uma unidade.
- Instalador baixado do servidor real, hashes idênticos, assinatura validada, instalação e segunda execução sem download: `work/combat-153-distribution.log` e `tests/ubuntu-distribution-results.json`.
- Inspeção do PCK público: granadas, números de dano, áudio de terra e arquivos fornecidos presentes; cena principal correta; cenas de QA e chaves privadas ausentes.

Todos os participantes devem abrir o atualizador antes de jogar. Os RPCs desta versão exigem clientes e servidor atualizados. O Modo Guerra permanece desabilitado na distribuição pública.
