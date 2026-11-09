# R2C PoseFrame — primeiros benchmarks GTX 1650 / 09-11-2026

Branch ia/realismo-r2c-poseframe-resume-20261109. JJ7, i5-11400H + NVIDIA GTX 1650, Godot 4.7.2.

## Controle real
Quatro coletas **válidas**: Favela offline, bots autoritativos 0/12/22/28, movimento real do jogador local com G3, flags R1/R2B/R2C explicitamente ON, 1920x1080, Forward+, Médio 100%, VSync OFF, física 60Hz, foco integral, população inalterada, jogador vivo e R2C ativo. Sem outros processos Godot.

**IMPORTANTE:** 4 segundos de aquecimento e **10 segundos medidos por cenário**. Amostra de diagnóstico, não A/A, não A/B, não valida estabilidade de uma sessão longa ou multiplayer. A câmera de benchmark não é equivalente à experiência cliente ENet.

| Bots | FPS médio | P95 quadro (ms) | P99 quadro (ms) | Física média (ms) | GPU média (ms) | Quadros R2C ativo |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 149.19 | 9.12 | 10.70 | 4.01 | 4.11 | 180 |
| 12 | 100.65 | 14.16 | 15.65 | 8.71 | 3.95 | 118 |
| 22 | 60.66 | 24.09 | 30.10 | 13.88 | 5.55 | 69 |
| 28 | 44.46 | 32.15 | 35.49 | 16.24 | 7.38 | 50 |

Todos os cenários retornaram exit code 0, valid=true e foco 100%; quatro arquivos JSON brutos completos acompanham o relatório em docs/benchmark-results/r2c-jj7-20261109/.

### Interpretação
Com 22 bots, nesta janela curta, a média ficou perto de 60 FPS e o P99 abaixo de 33,3ms. Com 28 bots o FPS caiu e P99 superou 33,3ms. Isso demonstra custo de população nesta configuração, **não** ganho atribuído ao PoseFrame: não houve par OFF/ON controlado. Outras configurações, câmera, combate e rede mudam os números.

### Integridade e pendências
- Na worktree nova, 129/129 testes de contrato PoseFrame, 172/172 testes adicionais de estados e 105/105 do piloto R2C (406/406 reexecutados), exit 0.
- O driver de benchmark foi corrigido em duas tipagens GDScript antes das coletas; check-only Godot também passou.
- O trabalho da outra IA ficou preservado na sua própria worktree, com as reservas originais mantidas. O código foi commitado usando o hook de segurança, sem --no-verify.
- **R2C continua experimental OFF por padrão** e apenas local offline TPP.
- Exigidos ainda: A/A e A/B alternados 5 pares x 60 s, suporte físico ao P1k de 16 regiões com equivalência completa, multiplayer ENet/DTLS, tiros/dano e importação fria. Nenhum merge em main ou publicação de build.