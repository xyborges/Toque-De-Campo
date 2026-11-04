# Atualização 1.6.7 — correções primeiro

## Escopo

Primeira entrega: fumaça/FPS, restrição de térmica e sniper. Recursos novos e balanceamento de veículos ficam para a próxima publicação, conforme ordem solicitada.

## Causas e mudanças

A fumaça usava esferas transparentes de dupla face, sete volumes por disparo pesado, com crescimento e duração que acumulavam dezenas de camadas diante da óptica. Agora utiliza QuadMesh billboard com opacidade suave, compactação de instâncias vivas, três emissões pesadas/uma leve, intervalos por emissor, limite de tamanho perto da câmera e LOD de fumaça de disparo a280m. Continua no pool256, sem criar nós por tiro, mantendo efeitos de impacto/explosão e saída traseira.

A térmica só pode ser ativada pelo operador na óptica FPP de um blindado. Trocar para TPP desliga o sensor. Passageiros e drone não o habilitam. As varreduras não reatribuem overlays iguais. [MultiMesh, documentação oficial](https://docs.godotengine.org/en/stable/classes/class_multimesh.html).

Sniper: range300→2200m, velocidade168→620m/s, gravidade12 mantida, arrasto.035→.008. A duração em Guerra recebe margem para o arrasto, mantendo a distância percorrida como limite autoritativo. As regras compartilhadas também atendem Offline e Deserto. Não há compensação artificial da mira nem impulso vertical. O requisito novo de alcance substitui a expectativa antiga de teste de queda maior que todas as armas à mesma distância; a gravidade continua maior que9.81, mas a velocidade reduz a queda acumulada.

## Medição antes/depois

Cenário nativo isolado, GTX1650, resolução real1920×1080, Compatibility, BMP-2 disparando pela mesma óptica4× com intervalo.24s, com e sem térmica. Seis segundos por etapa, primeiro segundo fora da amostra. A referência inicial1055px foi refeita em1080p.

| Etapa | Frame médio antes | Depois | 1% low antes/depois | P95 antes/depois |
|---|---:|---:|---:|---:|
| idle_normal | 2.459ms | 2.341ms | 230.0/272.3FPS | 3.276/3.043ms |
| fire_normal | 6.076ms | 2.490ms | 55.3/200.7FPS | 8.797/3.368ms |
| idle_thermal | 2.602ms | 2.455ms | 201.5/255.4FPS | 3.624/3.180ms |
| fire_thermal | 6.854ms | 2.802ms | 101.1/150.2FPS | 8.802/4.121ms |

São FPS de diagnóstico numa cena pequena, não da partida completa; não equivalem a promessa de400FPS nem60estáveis para12jogadores. Durante fogo, máximo de fumaças vivas caiu de74–75 para40. Inspeção nativa confirmou que a fumaça continua visível.

## Validação

- 18 verificações: alvos físicos corporais em300/800/1200/1800/2000m, colisão varrida real, compensação dentro da luneta7° e trajetória45° comparada à integração compartilhada (erro3mm em240passos).
- 80 verificações nativas de lançadores/veículos/passag./câmeras/térmica e parede; inclui desligamento ao alternar para externa e recusa emTPP.

Resultados: `tests/war167-smoke-before.json`, `tests/war167-smoke-after.json`, `tests/war167-sniper-results.json`, `tests/war165-equipment-results.json`.

Arquivos: `scripts/weapons.gd`, `scripts/combat_rules.gd`, `modes/war/scripts/effects.gd`, `modes/war/shaders/smoke.gdshader`, `modes/war/scripts/thermal.gd`, `modes/war/scripts/vehicles.gd`, `modes/war/scripts/projectiles.gd`, `modes/war/scripts/rules.gd`; notas em`distribution/release-notes.json`.

Publicação concluída1.6.7/build33, protocolo Guerra6. A segunda etapa começará após esta publicação.


Regressões finais: combate48/48, ENet27/27, ópticas49/49, HUD50/50. PCK real inspecionado e câmera nativa8/8. Atualizador instalado e sem download repetido. Ubuntu build33 ativo: lançadores15/15 e Deserto com duas contas, tiros e granadas replicados. O primeiro probe de Deserto foi lançado headless; repetido no modo nativo apropriado, passou. Fonte/code e teste de tela não foram enfraquecidos para esconder esse erro de execução.
