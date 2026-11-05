# Favela — auditoria independente da ocupação das bordas (05/11/2026)

## Escopo e preservação

Esta revisão **não modifica a geração do mapa**, pois outra IA já está atuando nos arquivos
`favela_map.gd`, `favela_street_art.gd`, `favela_street_space.gd` e no manifesto.
Foi criada a branch `ia/favela-street-review` a partir do commit **f8a5654**
na worktree `campo-worktrees/favela-street-review`, sem tocar na `main`.

O arquivo `tests/favela_spatial_review.gd` é um teste read-only da planta
determinística: valida footprints de lotes, folga viária e distância entre
borda de rua e casas, sem montar cenas físicas nem substituir auditoria visual.

## Diagnóstico reproduzível — baseline v4

Godot 4.7.2 headless, mesmos resultados na worktree commitada e em leitura
da worktree `favela-guerra` com as alterações viárias ainda em andamento.

| Medição | Resultado |
| --- | ---: |
| Lotes | **3.845** |
| Corredores viários | **18** |
| Amostras de borda | **5.816** |
| Lotes com footprint em sobreposição | **0** |
| Lotes com footprint invadindo pistas | **0** |
| Menor folga calculada da edificação à pista | **0,437 m** |
| Bordas com casa a até 5 m | **64,7%** |
| Bordas com casa a mais de 15 m | **6,0%** |
| Lotes com variação vertical centro/canto acima de 3 m | **621** |
| Lotes com variação vertical centro/canto acima de 7 m | **36** |

### Locais que merecem inspeção adicional

- **Avenida principal** (via 0, largura 10,5 m): 205/462 amostras
  com fachadas a até 5 m e 35/462 com casas além de 15 m. Pior folga
  de 22,6 m perto de **(-439, 457)**. Atenção a recuos e transição para a base.
- **Travessa z=340** (via 1, largura 6,8 m): **120/470** amostras com casas
  além de 15 m, pior próximo de **(-510, 345)**. Região prioritária para
  composição de muros de contenção, becos, escadas e fachada, se o local for seguro.
- **Via x=560** (via 11, largura 3,8 m): 74/410 amostras com casas
  a mais de 15 m, especialmente em **(563, 480)**; parte está na
  borda de expansão urbana, onde a transição à mata/terreno aberto pode ser intencional.
- Trechos com declividade local acima de 25%:
  avenida principal, algumas vias x=-320 e x=-105 e minivielas.
  Picos de 63,6% foram encontrados em minivielas — **não são rotas para Guarani**.
- Os 36 lotes com desnível centro/canto superior a 7 m devem ser
  inspecionados por possível submersão parcial de paredes ou base flutuante.
  É importante não eliminá-los indiscriminadamente: morro e verticalidade
  também fazem parte da proposta.

## Distinção entre erros

**Planta de casas ≠ colisão total do cenário.** Os footprints não se
sobrepõem; podem existir colisores de toldos, telhados, comércio, veículos
estáticos, postes e pavimentos que passam da divisa do lote.

A auditoria da outra IA, fornecida pelo usuário, registrou **238.926 raios**,
**91 colisores invadindo ruas e 44 cruzamentos com faces quase coplanares**
no estado anterior, contra **0 / 0** após o protótipo da correção.
Esses números representam o teste de raycast/interseções específico,
não prova de gameplay, de qualidade artística ou de todas as colisões.

## Teste e regras de regressão

```powershell
$project='C:\Users\Joao Borges\Documents\campo-worktrees\favela-street-review'
$godot='C:\Users\Joao Borges\Documents\Codex\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path $project --script res://tests/favela_spatial_review.gd
```

Falha se ocorrer interseção de footprints, invasão viária, folga mínima
inferior a 35 cm, menos de 60% de bordas com casas a até 5 m,
mais de 9% de bordas com casas além de 15 m, ou amostragem insuficiente.

Os limiares são **guardrails** de regressão do mapa v4, não a aprovação final
da estética ou da trafegabilidade. A validação da correção em andamento exige
comparação visual dos mesmos ângulos, raycasts do ambiente completo e
ensaios de navegação e veículos; a tela não foi capturada por esta branch.

## Integração

Levar **apenas** o teste `tests/favela_spatial_review.gd`, seu UID
e esta documentação ao integrador. Não copiar diretórios entre worktrees,
não sobrescrever a correção viária ativa, não fazer merge na `main`
e não publicar build. Após o outro trabalho concluir, executar novamente
este QA e o teste físico `favela_streets_qa.gd` lado a lado.
