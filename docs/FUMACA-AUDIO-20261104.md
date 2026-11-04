# Integração de áudio de fumaça — 04/11/2026

## Origem e reprodução

Áudios recebidos do usuário, comparados por SHA-256 com as cópias presentes no computador:
- `audio/smoke/tank_smoke_launch.mp3` — 5,9 s, mono/48 kHz; reprodução única quando a cortina do blindado é lançada. SHA-256 `d04c06ca4912a8c6e328fc77fe9987cd8f19947f7a881c03f611e77f030a70d9`.
- `audio/smoke/hand_smoke_start.mp3` — 2,8 s, mono/48 kHz; reprodução única na emissão da M18, não no momento de retirar o pino. SHA-256 `a2705a872a9dc6c006ae02899f8080863dabddf131104263cc1279dfb4003db3`.
- `audio/smoke/smoke_hiss_loop.mp3` — 6 s, mono/48 kHz; loop reutilizado pelo sistema de nuvens, com volume suavizado por fase. SHA-256 `aa7f878746ff383efae9d12f1a8d472b030cae59ca7581da1eca14873b4206ef`.

Os arquivos foram preservados sem edições. O loop é reproduzido usando o `AudioStreamMP3.loop` nativo, com início e saída graduais; para eventual tratamento de costura/crossfade na amostra, fazer uma versão masterizada à parte, não substituir a original silenciosamente.

## Integração

- `scripts/smoke_audio.gd` é um controlador cliente 3D de vozes pré-alocadas.
- `scripts/smoke_clouds.gd` notifica o controlador ao criar nuvens já recebidas pelo pipeline de eventos existente. Não existe evento RPC adicional, física por partícula, novos timers em servidor nem mudança na lógica dos bots.
- Fumaça de blindado: som inicial no mesmo ponto dos lançadores, bus `Veiculos`; chiado 3D com raio de seleção até 150 m no bus `Ambiente`.
- M18 de mão: som inicial ao terminar o pavio no local da granada, bus `Efeitos`; chiado no bus `Ambiente`, raio até 95 m.
- Fumaça dos blindados: áudio de início só para eventos recentes (menos de 0,35 s), encerrando a possibilidade de "salvas" atrasadas em jogadores que entram na partida em andamento. Um late joiner pode ouvir apenas o chiado da cortina ainda ativa.
- Atraso do loop: 3,3 s em blindados e 2 s em M18, para não empilhar a parte forte da gravação de ativação. O chiado cresce por 2,6 s, permanece audível e vai diminuindo nos últimos 17 s da vida da nuvem.
- Prioridades: próximas quatro nuvens audíveis com limites de 95/150 m. Troca de fontes com fade-out curto, sem cortar imediatamente eventos em primeiro plano. Máximo de **5 vozes de início + 4 vozes de chiado por cliente**. Cada cortina usa um loop, jamais um para cada puff.
- Ao limpar ou encerrar a partida, todas as vozes são interrompidas; servidor dedicado headless não instancia os players.
- O grupo `spatial_sfx` continua presente para a limpeza global do jogo. O grupo `war_spatial_audio` foi intencionalmente evitado, porque o processamento periódico daquele grupo redefine volumes/buses e quebraria o envelope do chiado.

## Ajustes, riscos e testes

- Ganho inicial de tanques `-3 dB`, M18 `-5 dB`, chiado entre `-14 dB` (tanques) e `-17 dB` (M18), antes da redução progressiva e da atenuação 3D. Todos seguem os controles de `Veiculos`, `Efeitos` e `Ambiente` já existentes. Níveis são ponto de partida, sujeitos a revisão auditiva no cliente gráfico.
- Os sons MP3 originais têm duração suficiente e escala menor que os sons de combate; não há sidechain ou ducking novos.
- O teste headless valida recursos, alocação zero no servidor, limites, distâncias, duração e lógica de fade; não reproduz áudio efetivamente. Conferir em cliente gráfico: costura do loop ao completar 6 segundos, mixagem com explosões, perspectiva em cabine, balanço entre mapas, volume de múltiplas fontes simultâneas.
- O uso simultâneo com 28 bots é protegido pelo limite de 9 vozes, mas precisa de benchmark de GPU/áudio em cliente real antes de publicar.

## Testes

`tests/smoke_audio_20261104.gd` — importação, stream nativo, envelope e orçamento de vozes.
`tests/smoke_grenades_20261104.gd` — regressões de fumaça, 54 verificações do sistema existente.
