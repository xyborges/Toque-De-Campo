# Preparação dos mapas — Afeganistão v13 e Ucrânia — 03/11/2026

**Status:** aplicado ao projeto de desenvolvimento local e validado. **Não publicado em produção.**

## Objetivo e preservação

A base da atualização afegã é `docs/AFEGANISTAO-ADENSAMENTO-ETAPA3-20261103.md`. Os arquivos dessa etapa permaneceram intactos: 12 abrigos, 32 trechos de muro, 84 microdetalhes visuais, 375 pontos de loot anteriores, 12 depósitos novos, spawns autorais antigos e nova variação de semente de partida. Nenhum desses objetos ou posições foi apagado, deslocado ou recriado manualmente.

A Ucrânia não recebeu mudanças diretas de terreno nesta tarefa. Seu manifesto anterior havia ficado desatualizado depois de alterações em scripts de mundo, IA, UI, veículos e áudio; foram preparados novos recursos a partir das fontes existentes.

## O problema de navegação v13 encontrado

A versão preparada anterior não tinha regiões finas específicas para os 12 abrigos rurais. O mapa físico passava nas colisões, mas os 12 depósitos novos não eram alcançáveis pelos caminhos dos bots. Regenerar só os arquivos sem atualizar `prepare_routes.gd` deixou 0/12; a primeira adição de regiões e links avançou para 8/12; apontar os links ao componente do armazenamento melhorou para 11/12.

O último abrigo ainda estava ligado a um pequeno componente externo isolado. A correção final exige que cada link alcance um componente outdoor conectado à origem da navegação e tenha corredor físico livre. **Resultado: 12/12 depósitos v13 alcançáveis.** A própria validação rejeita a preparação caso algum depósito deixe de ter caminho.

## Arquivos aplicados ao projeto principal

- `modes/battle_royale/navigation/prepared/`: 115 regiões, 508 links (12 v13), 629 pontos seguros de spawn conectados, 292 pontos de loot *navegáveis*; o total de loot autoral continua 375+12.
- `maps/prepared/afghan/`: manifesto versão **10**, atualizado com a navegação vigente, 7 recursos preparados.
- `maps/prepared/ukraine/`: manifesto versão **13**, 8 recursos preparados.
- `work/br-nav-bake-source/`: 400/400 blocos de origem regenerados a partir do terreno atual.
- `modes/battle_royale/navigation/prepare_routes.gd`: gerador atualizado para preservar rotas dos 12 abrigos da v13.
- `tests/br_navigation_v13_prepare.gd`: nova prova reproduzível de 12 abrigos alcançáveis.
- `tools/verify_prepared_maps_v13.py`: teste de integridade independente para repetir após alterações em qualquer fonte.

Nenhum arquivo do mapa afegão v13, física, armas, áudio, HUD, servidores ou geração de loot foi editado durante esta reconstrução.

## Resultados

| Teste | Resultado |
|---|---|
| Integridade de origem (Ucrânia 122 arquivos, Afeganistão 105, BR nav 68) | 295 verificações de arquivo no snapshot sem divergência |
| Preparação física BR | 400/400 blocos completos |
| Reconstrução de rotas BR | 115 regiões, 12 links v13 |
| Validação de navegação BR | **341 verificações sem falhas** |
| Depósitos v13 alcançáveis pela navegação | **12/12** |
| Preparação mapa Afeganistão | **20/20** |
| Validação posterior Afeganistão | **13/13** |
| Preparação mapa Ucrânia | **22/22** |
| Validação posterior Ucrânia | **14/14** |
| Colisões e entradas v13 | 12 abrigos, 32 muros, 12 entradas livres |
| Seleção BR com navegação nova | 40 jogadores nas 8 rodadas; 8 células iniciais distintas |
| Loot BR v13 | **375 pontos anteriores + 12 novos**, 12/12 novos com drops, 742 drops na simulação |
| Verificador de integridade no projeto principal | **11/11** |

Os testes de mundo anterior também identificam candidatos e marcadores de loot históricos que não integram a componente navegável. Isso **não é uma afirmação de que todos os pontos autorais antigos são acessíveis por bots**; a validação prioriza os limites de cobertura da suíte existente e os 12 depósitos novos.

Avisos de encerramento conhecidos do Godot/Jolt: 2 RIDs de forma não liberados e 2 recursos ainda em uso durante saída headless. Os processos concluíram as preparações e validações com código 0, e o caso permanece anotado para limpeza de recursos.

## Integridade, cópia e reversão

- Cópia independente usada para geração e validação: `C:\Users\Joao Borges\Documents\campo-map-prep-v13-20261103`.
- Backup de todos os diretórios e do gerador substituídos: `work/map-prep-v13-backup-20261103-230856/`.
- Registro da promoção: `work/map-prep-v13-last-promotion.json`.
- O instalador verificou todos os hashes antes e depois de copiar as saídas e recusaria alterações concorrentes dos arquivos-fonte. A promoção terminou sem rollback.

Para conferir a integridade após outras atualizações:

```powershell
python tools/verify_prepared_maps_v13.py
```

Se uma fonte mudar novamente, o verificador deverá rejeitar o manifesto desatualizado. **Não corrija hashes manualmente** nem desative o bloqueio de versão online.

Para reverter, desligue os processos Godot que estejam consumindo os dados preparados e restaure os caminhos correspondentes de `work/map-prep-v13-backup-20261103-230856/`, preservando a estrutura relativa. Não sobrescreva versões mais novas de outros trabalhos sem comparar seus hashes.

## Pendências antes de publicar

1. Benchmark real em 1920×1080 na GTX 1650 com **28 bots**, a ser conduzido pelo trabalho paralelo de otimização; a preparação não implica desempenho aprovado.
2. Validação de dois executáveis completos em máquinas distintas no BR e na Guerra: conectar, admitir, receber a baseline, implantar, morrer, reimplantar, desconectar e reconectar.
3. Reiniciar clientes/servidores de teste para recarregar dados preparados. Builds/exportações antigas não contêm a mesma versão e devem ser atualizadas junto ao servidor.
4. Repetir `python tools/verify_prepared_maps_v13.py` **depois de qualquer modificação** dos arquivos de mundo, vegetação, navegação, IA, HUD ou áudio que entre na lista de fontes dos manifestos.

Não foram restaurados logs nem registros históricos apagados. O relatório original da etapa 3 foi preservado.

## Prova final executada no diretório principal
- `tests/map_v13_identity_smoke.gd`: **exit 0** no Godot 4.7.2. Afeganistão v10 compatível, Ucrânia v13 compatível, alteração fictícia de hash rejeitada em ambos e `BRNavigation` com manifesto completo e 12 regiões v13.
- `tools/verify_prepared_maps_v13.py`: **11/11 verificações** aprovadas, inclusive correspondência de todos os recursos preparados e fontes em disco.
- Esses testes apenas validam identidade e recursos; não substituem o teste com servidor remoto, dois clientes exportados ou o benchmark de 28 bots.
