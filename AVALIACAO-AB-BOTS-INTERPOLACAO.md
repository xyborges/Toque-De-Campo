# Guerra — avaliação A/B de bots e interpolação

Análise local sobre a versão 1.9.7, sem publicação. Os testes não alteraram o servidor nem os scripts de jogo. O protótipo de LOD existe exclusivamente em `tests/perf200_bot_lod_prototype.gd` e é acionado apenas pelo projeto de benchmark.

## Método

Em cada série foi usado o bloco **A/B/A/B/A/B/A**: quatro referências A e três experimentos B, terminando com referência. Cada execução teve 25 segundos, com 3 segundos iniciais excluídos. Semente 193, câmera fixa, 18 participantes (um humano local e 17 bots), Jolt e 60 ciclos por segundo, mesma cena e GTX 1650. O benchmark mostra os bots saindo das bases; os registros indicam zero disparos no intervalo medido. Ele não representa combate intenso, movimentos de câmera de jogador nem 18 clientes conectados.

A resolução da textura renderizada foi **1920 × 1080**, viewport **1920 × 1080** e tela **1920 × 1080**. A janela cliente era 1920 × 1055 por causa da área útil do Windows; a textura em 1080p foi ajustada à janela. O número 1965 × 1080 do teste anterior resultava do modo `expand` do viewport de 1920 × 1080; o ensaio anterior não era 1080p exato. Não compare numericamente aquelas séries com estas como se fossem o mesmo cenário.

A telemetria foi amostrada aproximadamente a cada 3 segundos durante todas as referências e experimentos: temperatura, clock, uso e potência da GPU, além de clock estimado e utilização da CPU. O clock da CPU é a estimativa do contador do Windows (frequência nominal × percentual de desempenho), não leitura direta de cada núcleo. O Windows negou acesso ao sensor térmico da CPU; sua temperatura é **indisponível**. A própria coleta consome recursos em A e B.

Nos quadros abaixo os dados são `FPS médio / 1% low em FPS / pior quadro em ms`. Números de sensores são médias das amostras durante cada execução. `CPU` é MHz estimado e `GPU` é MHz do núcleo, não clock de memória.

## Teto: direção dos bots interrompida

| Ordem | Condição | FPS / 1% / pior ms | GPU °C / MHz | CPU MHz estimado | Bots em veículos |
|---|---|---:|---:|---:|---:|
| A1 | normal | 55,0 / 32,4 / 34,8 | 70,8 / 1132 | 3683 | 4 |
| B1 | direção dos bots parada | 79,0 / 22,3 / 65,0 | 82,3 / 1346 | 3660 | 1 |
| A2 | normal | 50,7 / 31,4 / 32,9 | 74,2 / 1060 | 3562 | 4 |
| B2 | parada | 77,5 / 17,4 / 63,3 | 83,0 / 1395 | 3629 | 1 |
| A3 | normal | 53,8 / 33,5 / 35,6 | 75,2 / 1115 | 3638 | 4 |
| B3 | parada | 74,5 / 16,8 / 65,2 | 82,4 / 1301 | 3644 | 1 |
| A4 | normal | 53,8 / 33,9 / 44,5 | 75,5 / 1102 | 3642 | 4 |

A mediana aumentou de 53,8 para 77,5 FPS (+44%), mas o 1% low caiu de 32,9 para 17,4. **Isso não mede apenas movimento**: interrompe decisões, controle de veículos e disparos dos bots; suas trajetórias e a carga visual também mudam. Em B a GPU operou mais quente e em clock mais alto. É um teto exploratório, não um ganho transferível para o produto.

## Teto: bots sem usar veículos

| Ordem | Condição | FPS / 1% / pior ms | GPU °C / MHz | CPU MHz estimado | Bots em veículos |
|---|---|---:|---:|---:|---:|
| A1 | normal | 54,2 / 36,5 / 32,4 | 74,1 / 1095 | 3610 | 4 |
| B1 | bots fora de veículos | 56,2 / 34,1 / 34,6 | 75,3 / 1168 | 3702 | 0 |
| A2 | normal | 54,0 / 33,9 / 35,9 | 74,7 / 1128 | 3651 | 4 |
| B2 | fora | 49,5 / 28,7 / 40,4 | 74,3 / 1065 | 3590 | 0 |
| A3 | normal | 54,7 / 35,1 / 44,0 | 75,2 / 1150 | 3647 | 4 |
| B3 | fora | 52,3 / 35,4 / 34,6 | 75,0 / 1106 | 3621 | 0 |
| A4 | normal | 52,1 / 32,4 / 42,7 | 74,5 / 1080 | 3544 | 4 |

Medianas: 54,1 FPS A versus 52,3 B; 1% low 34,5 versus 34,1. O efeito é pequeno e inconsistente: sem passageiros há mais bots caminhando, e os veículos continuam existindo e sendo simulados vazios. Não prova quanto custaria remover os veículos do cenário.

## Protótipo de LOD de movimento dos bots

Quando elegível, o protótipo executa a movimentação com delta acumulado a cada três ciclos (20 Hz); o mundo continua a 60 Hz. Bots no ar, próximos a humanos, com alvo ou se aproximando de um veículo continuam em 60 Hz. A sequência de bots é escalonada. A simulação de veículos permanece em 60 Hz e quatro bots estavam neles em ambas as variantes.

| Ordem | Condição | FPS / 1% / pior ms | GPU °C / MHz | CPU MHz estimado | Passos reduzidos |
|---|---|---:|---:|---:|---:|
| A1 | normal | 52,7 / 28,4 / 41,7 | 72,0 / 1085 | 3629 | — |
| B1 | protótipo | 65,3 / 45,2 / 30,9 | 78,3 / 1365 | 3686 | 5172 |
| A2 | normal | 53,9 / 37,1 / 31,6 | 75,4 / 1123 | 3621 | — |
| B2 | protótipo | 63,1 / 47,4 / 25,6 | 77,8 / 1302 | 3638 | 5168 |
| A3 | normal | 47,0 / 26,7 / 47,9 | 72,4 / 994 | 3521 | — |
| B3 | protótipo | 47,5 / 4,1 / **1245,2** | 74,3 / 1078 | 3414 | 4851 |
| A4 | normal | 30,1 / 20,6 / 50,9 | 63,3 / 722 | 2406 | — |

Os dois primeiros pares sugerem economia promissora. No terceiro B ocorreu uma parada de 1,245 s; amostras próximas mostraram uso da CPU subir de 15% para 60%, clock estimado cair de 3736 para 2312 MHz e clock da GPU de 1185 para 450 MHz. A referência seguinte também mudou de patamar, confirmando uma alteração externa de condições ou estado do computador, mas **não identifica a causa da parada**. O ensaio é insuficiente para excluir o protótipo como causa. Não descartei a amostra, nem extrapolei o ganho para combate, outros computadores ou servidor.

O teste isolado de guardas confirmou que um bot distante no chão é escalonado, continua avançando, e retorna à taxa integral ao se aproximar de um humano ou adquirir alvo. Isso não valida colisão em escadas, prédios, veículos, projéteis, respawn ou jogo online completo com o LOD.

### Risco específico para autoridade do servidor

- Um inimigo pode acertar um bot distante com sniper, míssil ou explosão: estar a mais de 180 m **não** significa estar fora de combate. O servidor usaria uma posição/hitbox que só muda a 20 Hz enquanto disparos e colisões ocorrem a 60 Hz; há até dois ciclos sem atualização e o deslocamento pode aparecer em blocos. `move_and_slide` com delta acumulado também muda a resolução de obstáculos e a gravidade.
- A proximidade de **todos** os jogadores humanos precisa ser considerada no servidor, incluindo ingressos, observadores relevantes, distâncias em 3D e eventuais projéteis já em voo. Uma reação depois que o jogador se aproxima não recompõe colisões perdidas.
- O envio a clientes pode mostrar saltos ou criar dupla interpolação. O servidor deve manter a física e o estado de acerto coerentes com o que os jogadores veem, inclusive em mortes e troca de assentos.
- O protótipo é um cálculo exploratório, não uma solução segura. Foram preservados 60 Hz e a implementação normal em produção. Não adotar sem reproduzir o teste intercalado em condições estáveis, medição com tiros a longa distância e colisões em terreno, veículos, ragdoll, além de múltiplos clientes e validação no servidor headless.

## Interpolação seletiva: suavidade quadro a quadro

O teste criou um alvo de velocidade constante perpendicular a uma câmera fixa. A cada quadro foram gravados tempo, duração, posição projetada da transformação exibida, posição física e fração do ciclo. A transformação interpolada foi obtida por `get_global_transform_interpolated()`, conforme a [documentação do Node3D](https://docs.godotengine.org/en/4.7/classes/class_node3d.html). A métrica é o desvio padrão da velocidade projetada, em pixels/s: menor indica velocidade mais uniforme para **esse alvo controlado**. Não é captura de pixels, câmera de ombro, animação, tanque em terreno ou teste em monitor de 144 Hz.

| Ordem | Condição | FPS / 1% / pior ms | Desvio px/s | GPU °C / MHz | CPU MHz estimado |
|---|---|---:|---:|---:|---:|
| A1 | sem interpolação | 29,4 / 19,4 / 57,9 | 2,04 | 62,7 / 708 | 2415 |
| B1 | seletiva | 27,6 / 16,5 / 80,8 | 1,61 | 62,1 / 690 | 2419 |
| A2 | sem | 29,9 / 16,1 / 68,1 | 2,11 | 64,0 / 730 | 2415 |
| B2 | seletiva | 27,5 / 17,1 / 74,3 | 1,75 | 62,7 / 695 | 2419 |
| A3 | sem | 30,7 / 19,6 / 59,3 | 2,42 | 66,0 / 735 | 2412 |
| B3 | seletiva | 28,7 / 20,3 / 54,5 | 1,40 | 60,7 / 705 | 2408 |
| A4 | sem | 32,1 / 22,0 / 52,9 | 2,79 | 61,2 / 752 | 2406 |

O desvio mediano foi aproximadamente 2,27 px/s sem e 1,61 px/s com interpolação, uma redução de 29% nessa medição sintética; médias de velocidade cerca de 17,5 e 17,7 px/s. A mediana de FPS caiu de 30,3 para 27,6. A comparação ocorreu perto de 30 FPS e apresenta diferença de clocks da GPU. Portanto, há evidência de suavização da trajetória projetada controlada, mas **não uma validação visual nem ganho de desempenho**. Não foi ativada no jogo.

## Conclusão e próxima etapa

Os testes de teto apontam que vale estudar a movimentação dos bots; retirar motoristas dos veículos, isoladamente, não trouxe benefício convincente. O protótipo de 20 Hz merece investigação, porém o pico, a falta de combate e o risco de acertos distantes impedem incorporá-lo. Nenhuma otimização foi aplicada ao jogo. Uma etapa seguinte deve registrar atividade externa e repetir A/B em cenário de combate real e servidor dedicado, com disparos a longa distância e observadores, antes de qualquer decisão de adoção.
