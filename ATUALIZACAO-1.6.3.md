# Toque de Campo 1.6.3 — integração final

**Publicada no Ubuntu em24/10/2026, build29.** Jogo, API, site e launcher foram ativados pelo publicador assinado, após sua verificação de salas vazias. A revisão preparada como1.6.2 não foi publicada separadamente: suas alterações fazem parte deste pacote.

## Respawn, morte e câmera

A tela de implantação era aberta cerca de três segundos após a morte, enquanto a autoridade só liberava a nova vida aos quatro segundos. O menu não mostrava essa diferença. Além disso, a escolha salva durante a vida em `M` permanecia em `pending`, sem ser aplicada na próxima implantação. No treino offline, a câmera de morte podia continuar ativa depois de o personagem já ter renascido.

- A escolha explicitamente salva no M é consumida na próxima vida após os quatro segundos da autoridade. O menu mostra classe, equipe e ponto confirmados pelo servidor.
- O botão indica a espera restante. Sem uma escolha salva, o jogador continua no menu para decidir sua próxima implantação; não há seleção automática arbitrária.
- Se o setor escolhido foi perdido, a implantação retorna à base da mesma equipe. Quem já pertence à equipe mantém seu lugar de respawn mesmo após uma desconexão desequilibrar a contagem; novos integrantes continuam sujeitos ao balanceamento.
- Implantação encerra a câmera de morte e devolve a câmera do personagem. Reinício de operação limpa as escolhas anteriores.
- Em TPP, o SpringArm encurtado por um obstáculo não ativa mais o modelo de primeira pessoa. Cabeça/equipamentos que se sobrepõem à câmera são ocultados sem trocar o modo escolhido.
- Recarga, troca de arma e mensagens tardias de recarga não alteram um personagem morto. A granada armada continua caindo com seu pavio original ao morrer.

## Lançadores e lunetas

RPG-7 e Stinger passam a ter identidades de arma reais, restritas à classe Antitanque de Guerra. O inventário da infantaria original não vende nem equipa esses itens fora desse modo. Os atalhos 7 e 8 e os botões contextuais do HUD escolhem o equipamento real, com modelo, mãos, cano e óptica correspondentes.

As cargas de classe continuam compartilhadas, validadas pelo servidor. Não foram fabricados carregadores independentes. O Stinger conserva suas condições de aquisição/trava; um pedido de disparo com lançador guardado é recusado. O tiro sai do marcador do cano, preservando a simulação e o dano existentes.

Na sniper, o botão direito percorre **luneta → ampliação maior → sair**. Os campos de visão são 14° e 7°, com sensibilidade de 25% e 12% da normal. As marcas de um milirradiano são referências angulares; não são uma promessa de distância fixa, pois a queda depende da balística. Sair da luneta preserva a opção FPP/TPP anterior. RPG e Stinger também têm miras telescópicas.

Referências técnicas consultadas para identificar os lançadores: [RPG-7 — Australian War Memorial](https://www.awm.gov.au/collection/C315158) e [Stinger — RTX](https://www.rtx.com/raytheon/what-we-do/integrated-air-and-missile-defense/stinger-missile). Os modelos são procedurais do projeto, não cópias de fotografias nem arquivos obtidos dessas páginas.

## Iluminação, projéteis e HUD

- Guerra utiliza o relógio já replicado da partida no ciclo compartilhado: 24 horas em 480 segundos. O céu permanece nublado, com ambiente cinza de dia e preenchimento lunar à noite.
- Projéteis pesados receberam núcleo colorido e largura visual compensada pela distância/FOV, com limites. O mesmo pool de 512 projéteis e quatro segmentos por rastro permanece. Não se alteraram velocidade, gravidade, origem ou dano para tornar o desenho visível.
- Objetivos eram projetados apenas a cada 100 ms; ao girar a câmera, o desenho usava uma posição de tela antiga. Agora são projetados no quadro atual. Texto e distância usam cache a 4 Hz, sem reconstruir nós a cada quadro.
- A caixa do Deserto envia um único snapshot de inventário ao dono, protegido por vida e revisão. Observadores não recebem mais dados privados de munição sem necessidade. Reposição, alcance e intervalo de uso permanecem.

## Plano de áudio, placar, ranking, granadas e HUD

As partes que já existiam foram preservadas: placar com linhas reutilizadas, dados autoritativos e equipes/FFA; ranking global em menu separado; quatro slots; granada com pavio de cinco segundos, dano em área e oclusão por paredes; indicadores de recursos próprios de cada classe.

Foram encerradas as quatro lacunas identificadas na auditoria:

1. Guerra e Deserto compartilham filtros/reverberação de disparos distantes, sem ganho nem oclusão duplicados. Os disparos ganharam 1,5 dB, mantendo atenuação 3D, pools e limitador.
2. HUD mostra cargas e cooldowns realmente confirmados pela autoridade para cada classe e o lançador selecionado, preservando a munição da arma guardada.
3. A API registra também mortes online por ambiente/suicídio, com evento único por vida. A ordem entre morte e recompensa não duplica a morte. Não concede abates nem moedas por registrar uma morte. NPCs e treino offline não alimentam o ranking central.
4. Troca de arma/granada pausa a recarga; voltar retoma o tempo restante, sem concluir em segundo plano ou transferir munição duas vezes. Morte, nova vida, veículo e reinício limpam os estados.

O protocolo de Guerra é revisão 3: todos os clientes precisam atualizar.

## Evidências e limites

Publicação confirmada em `work/release163-publication.log`: `DEPLOYED build=29 version=1.6.3`. O download real, a assinatura, a instalação pelo launcher, a segunda abertura sem download e a inicialização normal foram aprovados em `work/release163-distribution.log`. O pacote exportado abriu o treino offline com um humano e onze bots, sem login, em `work/war-offline-pack-163.log` (quatro verificações). Recursos novos, músicas e modelos foram inspecionados no próprio pacote, sem fontes/testes/QA na distribuição.

Guerra central com duas contas reais:17 verificações aprovadas em `work/release163-central-war.log`, incluindo disparo, recarga, granada, classe, corpo remoto e placar. Registros específicos adicionais: `HUD-CAIXA-1.6.3.md`, testes `war163_*`, relatório de regressões em `tests/release163-regressions.json` e logs `work/release163-*`.

Validação local encerrada nesta etapa:

| Área | Verificações aprovadas |
| --- | ---: |
| Ópticas, categorias, mãos, cano e autoridade de RPG/Stinger | 49 nativas |
| Respawn, câmera e ações após morte | 28 locais; 18 em três processos ENet |
| Projeção dos objetivos e menu de implantação | 19 nativas |
| Atmosfera, relógio, tamanhos de projéteis e ganho sonoro | 24 nativas |
| Caixa de suprimentos e pacotes antigos | 19; mais duas rodadas reais com três clientes |
| Combate/granadas e dominação anteriores | 48 + 53 + 64 nativas |
| Equipamentos Guerra offline e HUD | 34 + 49 + 25 nativas |
| Assentos, retorno de blindados e sistemas Guerra | 91 + 41 + 79 locais; 24 passageiros ENet |
| Recarga pausada/retomada | 28 locais; 22 ENet |
| Persistência de mortes e autoridade da API | 10 de despacho; 153 contra PHP/SQLite isolados |
| Áudio 3D real entre dois processos | 198; 58 sons capturados |
| Física e troca de armas navais | 15 + 19 nativas |
| Publicação/rollback isolados | 14 |

O teste de respawn mediu abertura do menu em 3,011 s e implantação salva em 4,034 s. Foi também corrigido um callback de ragdoll que sobrevivia ao nó do cadáver: os timers agora pertencem ao corpo e desaparecem ao sair da partida. A repetição ENet não apresentou o erro de captura liberada.

Dois fixtures nativos curtos que criam/removem atmosferas durante a inicialização ainda registraram duas advertências de textura GL no encerramento. Os 24 e 28 casos funcionais desses fixtures passaram, mas seus logs não são tratados como encerramentos gráficos limpos. A rodada completa de 12 clientes não apresentou esses erros. Isso não é atribuído a um crash do usuário sem reprodução.

Desempenho: **59,20 FPS médios, 1% low 33,61, P95 19,15 ms e pior quadro 36,39 ms** na janela a 1080p, com todos os processos no mesmo PC. Não comprova 60 FPS estáveis. Metodologia e comparação em `GUERRA-DESEMPENHO.md`.

A bancada da caixa de munição não reproduziu o travamento relatado: três processos mantiveram cerca de 60 FPS antes e depois. Foi removido trabalho de rede/UI comprovadamente redundante; isso não comprova que todos os travamentos possíveis foram eliminados. Medições de 12 clientes devem ser lidas com seu 1% low e picos, não apenas o FPS médio.

O treino Guerra mantém um humano, cinco bots aliados e seis inimigos. Os bots usam infantaria; não pilotam blindados/drones nem utilizam autonomamente lançadores/granadas. As funções dos veículos e a autoridade online/offline são compartilhadas.
