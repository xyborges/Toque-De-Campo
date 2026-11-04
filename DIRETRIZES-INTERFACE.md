# Diretrizes de interface — Toque de Campo

Priorizar nome curto → ícone → informação necessária. Antes de acrescentar texto, verificar se o jogador realmente precisa lê-lo para entender a situação.

- Disponibilidade por equipe/classe deve ser comunicada pelas escolhas que aparecem. Usar RPG-7, Stinger, FAL e Granada, sem qualificadores de exclusividade.
- Slots não aplicáveis não aparecem no menu, inventário ou HUD. Quando um estado indisponível precisar continuar visível, usar apenas Indisponível e um estado visual discreto.
- Seleção é comunicada por destaque e ícones. Evitar repetir Selecionada, Permitida, Autorizada ou Carregada ao lado de cada item.
- Detalhes como dano, alcance e cadência ficam em painel secundário ao selecionar. Manter contadores e cooldowns que afetam decisões durante o jogo.
- RPCs, autoridade, sincronização e validações pertencem aos logs e ferramentas de desenvolvimento. Não mostrá-los como mensagens rotineiras.
- Confirmações e erros devem ser curtos e acionáveis. Não remover avisos necessários de falha de conexão, compra ou saída.
- Reutilizar FieldTheme, GameUI e os componentes compartilhados; preservar a paleta do login.

Aplicado na1.7.0 a implantação/loadout, sensibilidade, arsenal, personalização e telas navais revisadas.
