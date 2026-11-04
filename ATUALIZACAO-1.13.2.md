# Atualização 1.13.2 — G3, lunetas e carregamento de vegetação

**Estado:** candidata preparada; publicação ainda não executada.

**Data:** 04/11/2026

**Build publicada observada pelo preflight:** 88.

**Build candidata assinada:** 89 / 1.13.2.

## Conteúdo

- Refinamentos visuais do G3 e das lunetas Hensoldt 4× e Telescópica 8×, com ajustes de montagem, geometria e transições de mira.
- Atualização gradual das células de vegetação. O pool reutilizado limita cada quadro a até três células próximas e duas distantes, em vez de enviar todas as células pendentes no mesmo quadro.
- Mudança preparada pela branch `ia/perf-stutter-20261104` e integrada à `main` no commit `49296a8`.

## Verificações concluídas

- `tests/grass_stream_budget.gd`: passou; confirmou limite de upload, convergência do campo, teleporte e reutilização do pool.
- `tests/maps_prepared.gd`: passou em 11.992.060 verificações.
- `python tools/maps.py validate --map all --output work/maps`: cinco mapas sem erros; Ucrânia, Afeganistão, Deserto, Escritório e Naval.
- `python tools/maps.py prepare --map all --output work/release1132-maps`: cinco relatórios sem erros; recursos preparados regenerados pelo pipeline oficial.
- Preflight remoto: `PREFLIGHT_OK build=89`, com build 88 publicado.
- Instalação assinada local: 13 verificações sem falhas; o executável protegido iniciou e carregou o módulo DLL.
- A branch experimental de colisão FPP/TPP ficou fora da atualização: o ensaio comparativo de 28 atores mostrou regressão de p99 (10,60 ms para 18,43 ms).

## Limites e pendências

- A validação do uploader é sintética e confirma o limite de trabalho por quadro; ainda não foi feito benchmark gráfico A/B prolongado na GPU afetada. Portanto, esta alteração reduz a concentração de uploads, mas não prova uma queda específica de temperatura, consumo ou frequência de throttling.
- O validador do Afeganistão ainda rejeita uma âncora de spawn (161 de 162 válidas), condição conhecida e sem erros novos nesta preparação.
- A validação do deploy Linux ainda está pendente antes de declarar a atualização publicada.
