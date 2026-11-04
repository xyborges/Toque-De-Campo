# Toque de Campo 1.8.6 — combate e implantação no Guerra

## Comportamento corrigido

- **Respawn:** o servidor agenda a nova implantação antes de gerar o ragdoll. Falhas de apresentação não devem impedir o retorno após oito segundos. A seleção de base ou setor controlado é respeitada; se o setor deixou de pertencer à equipe, o destino passa para a base. O cliente pode solicitar novamente a vida já autorizada quando continuar mostrando o estado de morto. Essa consulta não cria um respawn nem altera vida, munição ou tempo de espera.
- **Recarga:** um cliente que ficou esperando a confirmação final consulta novamente o inventário do próprio jogador. O servidor devolve o estado real, com validação de vida e limite de frequência. O gatilho, o tempo até o próximo tiro e a espera de sincronização são limpos ao iniciar uma nova vida. APCs passam a iniciar a recarga também no último tiro da cinta, assim como os tanques já faziam.
- **Modelo em primeira pessoa:** a reconstrução da arma agora invalida a cópia de FPP mesmo se o identificador não mudou. Na implantação, o ID podia ser atualizado antes da geometria, deixando uma cópia da AK sob o ID da FAL. Isso foi encontrado na inspeção após o respawn e corrigido.
- **Uniformes:** ragdolls usam o material original do personagem, e não o shader temporário da visão térmica. A cópia não depende mais de uma conversão inválida de ShaderMaterial para StandardMaterial3D; a limpeza do corpo também ignora referências de material inexistentes.
- **Blindados destruídos:** deixam o modelo queimado visível, com um breve movimento de assentamento da arma, explosão e os efeitos existentes. O mesmo veículo é restaurado ao fim do timer de 60 segundos. Não foram adicionados fragmentos rígidos ou novas partículas por frame.

## Regras do mapa e armamento

Todos os cinco objetivos começam neutros. A implantação inicial oferece apenas **Base principal**. Setores entram na lista quando a equipe os controla; a seleção é preservada por identificador, não pelo índice da lista. O antigo spawn gratuito de linha avançada foi retirado da validação e do menu.

As bases passam a **(-1160, 18, 100)** e **(1160, 18, -100)**, separadas por aproximadamente 2,33 km. Estradas conectam as novas posições à malha existente e o terreno continua nivelado sob os pátios. Os veículos terrestres acompanham essas bases. Os portos mantêm suas posições. A caminhada do Guerra muda de **6,2 para 4,8 m/s**; corrida e agachamento conservam seus multiplicadores. Foi adicionada uma proteção explícita contra o limite do mapa pequeno do Deserto durante transições, embora a cena estável do Guerra já use sua própria identificação de mapa.

**AK, FAL, Glock, sniper, armas brancas e metralhadoras comuns não causam dano em tanques/APCs.** Apenas armas explicitamente classificadas como capazes de danificar blindagem podem alterar a integridade. Uma arma futura não ganha penetração por usar um identificador desconhecido. A rejeição acontece antes do dano, estatísticas, pontos e confirmação visual. O impacto metálico pode produzir faíscas sem número de dano. Navios e drones conservam suas regras próprias.

A Glock tem intervalo mínimo de **0,20 s**, antes 0,34 s, mantendo disparo semiautomático. FAL/Glock/AK têm núcleo e rastro com espessura ajustada à distância/FOV. A redução de traçantes para um a cada dois disparos dos fuzis permanece; todas as balas físicas continuam sendo simuladas. O poste frontal da mira de ferro da FAL passa de 2,5 mm para 1,2 mm no modelo.

## Postes

São objetos metálicos com colisão física consultada pelo projétil. Tiros geram as faíscas existentes e reduzem a resistência de 120 pontos. Ao quebrar, a parte superior cai, o fio acompanha e a energia do circuito é interrompida. Luzes e fios usam o estado de destruição enviado pelo servidor, inclusive para quem entra depois. Os restos permanecem na operação.

## Verificações e limites

O relato principal foi identificado pelo usuário como **Guerra online**. A recarga simples da FAL e o respawn offline não falharam no primeiro teste de diagnóstico; por isso não se atribui todo o relato a uma única causa presumida. Foram corrigidos os casos concretos acima e acrescentadas verificações de recuperação e repetição de ciclos de combate.

- Teste UDP/DTLS com servidor e dois clientes: carregadores completos de FAL/AK até zero, troca durante recarga, três tiros rápidos da Glock, recuperação de confirmação de recarga, APC atirando até esvaziar/recarregar/trocar de arma, morte do ocupante e retorno à base, nova recarga e disparo após a morte.
- Uma falha de apresentação do primeiro evento de respawn foi introduzida **somente no roteiro de QA**. A autoridade iniciou a vida aos oito segundos e a consulta de recuperação devolveu o cliente à base em cerca de nove segundos, sem criar outra vida. O caminho normal havia sido medido em aproximadamente 8,01 s.
- O servidor verifica que tiros comuns contra blindados não mudam integridade, pontuação, dano estatístico ou sequência de confirmação visual.
- Instância nativa renderizada: menu de implantação, neutralidade dos setores, novas bases, velocidade, materiais sob térmica, ragdoll, destroço/restauração do APC, contato do projétil no poste e faíscas, traçantes e alinhamento da mira após o respawn.
- Regressões: 45 verificações de degraus/apoio de veículos/materiais e 15 de estados de combate, granadas, Glock e AK.

Resultados e logs: `tests/bugs186-network-*.json`, `tests/bugs186-visual-results.json`, `work/bugs186-network.log`, `work/bugs186-visual.log`, `work/bugs186-regression-*.log`. Capturas em `work/bugs186-*.png`.

Resultado final: **31 verificações locais/visuais, 22 multiplayer e 60 de regressão passaram**. No ciclo do APC, o servidor registrou 35 projéteis, 25 tiros restantes e 100 em reserva após a recarga. Os testes também cobrem a recusa de dano de um identificador de fuzil futuro e a conservação dos pontos e estatísticas do atacante.

### Checagem no Ubuntu e comunicação de contas

O primeiro pacote desta atualização, build 56, foi publicado e o download/instalação pelo launcher foi conferido. Uma checagem adicional com duas contas reais identificou falhas de preparação do teste (o cliente sem gráficos não pode capturar o mouse e o teste da Equipe 2 ainda procurava munição da FAL em vez da AK). Essas falhas do roteiro foram corrigidas.

Após isso, repetiu-se no cliente com gráficos um timeout da consulta HTTPS de perfil durante o carregamento do mapa, enquanto a outra conta conseguia entrar. O `HTTPRequest` de `NavalAccounts.call_api` foi alterado para `use_threads=true`, permitindo progresso de TLS/HTTP separado dos frames de renderização. Certificado, validação de assinatura do perfil, limites de tamanho, proibição de redirecionamentos e tempo limite de oito segundos foram preservados.

Com o ajuste, **17 verificações adicionais passaram no servidor Ubuntu**, com duas contas autenticadas: implantação de ambas as equipes nas novas bases, FAL com tiro aceito pela autoridade e recarga iniciada, explosão de granada recebida por ambos, presença no placar e modelo remoto visível. Os clientes não usaram bypass de autenticação ou autoridade. Logs: `work/bugs186-central-war.log`, `tests/ubuntu-war186-host.json`, `tests/ubuntu-war186-guest.json`. O ajuste de contas integra o pacote final da 1.8.6.

Estes testes verificam comportamento e sincronização. Não são uma medição de FPS de combate com 12 jogadores. O protocolo de implantação passa para 6 e o do Guerra para 18; todos precisam atualizar para a mesma versão.

## Publicação final

Ativado no Ubuntu como **1.8.6, build 57**, em 26/10/2026, incluindo o ajuste de comunicação das contas. O publicador confirmou salas vazias antes da ativação e verificou os serviços. Site, notas, launcher, pacote do jogo e servidor correspondem ao mesmo manifesto assinado. Evidências: `work/bugs186-deploy-final.log`, `work/bugs186-package-final.log`, `work/bugs186-download-final.log`.
