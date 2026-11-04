# Atualização 1.5.4 — granadas, efeitos e visibilidade

## Jogabilidade

- **7** equipa uma granada ainda desarmada. Segure o botão esquerdo e solte para lançar. **G** continua como atalho direto, sem precisar selecionar o slot.
- O pavio de **8 segundos começa ao armar**. A quantidade é descontada uma única vez nesse momento. Arremessar preserva o restante do pavio; segurar até zero explode na mão. Morrer ou desconectar solta a mesma granada armada, sem reiniciar o tempo.
- A arma de fogo sai das mãos durante preparação e arremesso. Disparo, recarga e mira da arma são bloqueados; depois do gesto, volta a arma anterior. Há apresentação em primeira e terceira pessoa e sincronização de seleção, preparação, arremesso, queda e explosão.
- A guia da granada é um arco simples, grosso e azul petróleo (`#155e6b`), até o primeiro contato ou o limite curto de previsão. Não desenha a sequência completa de quiques. A granada real mantém colisão, gravidade e quique.
- Continuam duas granadas por vida, raio de seis metros, redução por distância e três amostras de cobertura no servidor. A guia é uma indicação de primeiro contato, não uma promessa do ponto final após quicar ou encontrar objetos em movimento.

## Bugs e aparência

- **Corpos invisíveis no Deserto:** `_update_view` aplicava a ocultação da primeira pessoa também a avatares remotos. Agora essa condição exige `is_local`. Respawn restaura a apresentação completa de todos os avatares.
- **Dano gigante com zoom:** o número usava escala que não compensava a projeção da câmera. Agora a escala considera profundidade, altura do viewport e projeção vertical real. Fonte de 18 pixels, vermelha `#ef4141`, contorno escuro; sem aumento especial para crítico. Continua no mundo 3D, respeitando oclusão, deduplicação e confirmação do dano real pelo servidor.
- A escala do número é aplicada já ao obter o rótulo do pool, evitando um quadro com o tamanho da utilização anterior. Há no máximo 48 rótulos ativos.
- Traçantes com cores saturadas por arma e contorno escuro, com menos emissão branca. A própria bala é a origem do rastro. FAL e metralhadoras mostram um traçante a cada dois tiros; Glock, sniper, míssil e torpedo mantêm todos. Física, acertos, munição, sons e validação continuam em todos os tiros.

## Custo dos disparos

- Geometria de baixa complexidade, materiais compartilhados e pool de até 256 apresentações de projétil. O servidor sem renderização não aloca essas apresentações.
- Pequeno clarão e fumaça em quads substituem esfera densa, luz dinâmica e temporizador criados a cada tiro. Efeitos limitados a 64 simultâneos; impacto com sangue mantém cor vermelha.
- Consulta física de cada projétil é reaproveitada; câmera é obtida uma vez por passo. Remover metade dos rastros não remove metade dos tiros.
- A versão anterior também produziu erro de captura de lambda ao encerrar o benchmark do Escritório. O log foi preservado como evidência histórica. Nenhum erro dessa categoria foi aceito nos testes da versão atual.

## Nuvens e relógio

- Offline, PVP Deserto e Naval usam ciclo de 480 segundos para 24 horas. Nuvens, sol, luz de lua, cores de céu e ambiente acompanham o horário.
- PVP recebe horário do servidor ao entrar e a cada dois segundos. Naval usa seu relógio de snapshots existente. O relógio das ondas e da balística naval não foi trocado nem reiniciado a cada dia.
- Modo Guerra permanece desabilitado e fora desta entrega.

## Medições antes e depois

Godot 4.7.2, OpenGL Compatibility, GTX 1650 / driver 610.62, janela sem borda **1920×1080**, limite de 60 FPS, `--debug --profiling`. Cenários reais do Deserto e Escritório, câmera fixa e NPCs desabilitados para repetir a carga. Cada caso durou seis segundos, descartando o primeiro. Sem outro teste Godot ou exportação durante a medição. O baseline preserva o renderizador antigo em `work/before-1.5.4`; usa o personagem atual imóvel. É comparação das alterações combinadas de apresentação, não isolamento perfeito de cada mudança.

| Mapa / fontes de disparo | FPS antes → depois | 1% low antes → depois | Quadro médio ms antes → depois | Pior quadro ms antes → depois | Triângulos de pico antes → depois |
| --- | --- | --- | --- | --- | --- |
| Deserto / 1 | 58,86 → 58,91 | 24,18 → 18,75 | 16,99 → 16,97 | 47,02 → 72,37 | 541.714 → 438.206 |
| Deserto / 6 | 56,69 → 59,53 | 18,08 → 28,95 | 17,64 → 16,80 | 66,94 → 55,84 | 825.802 → 415.304 |
| Escritório / 1 | 59,98 → 59,72 | 30,82 → 31,72 | 16,67 → 16,75 | 35,18 → 42,58 | 164.646 → 94.572 |
| Escritório / 6 | 59,36 → 59,74 | 21,18 → 26,79 | 16,85 → 16,74 | 57,68 → 42,62 | 483.366 → 95.024 |

As médias melhoraram sob carga de seis fontes, mas há picos e variação de escalonamento. O caso de um atirador no Deserto teve **1% low pior**: não foi omitido. Não se afirma 60 FPS estáveis nem validação de 12 jogadores. A medição usa fontes sintéticas de disparo com áudio e física reais, não seis clientes completos.

A bateria inclui casos sem clarão e sem traçante. No Deserto atual, sem clarão: 59,83 FPS / 26,69 de 1% low; sem traçante: 59,89 / 28,03. O custo visual caiu, mas esses dados não demonstram que um único efeito explica todos os picos. Resultados completos: `tests/combat-render-{before,after}-{desert,office}.json`; perfis e stdout em `work/render-154-*`.

## Validação

- Teste nativo da nova atualização: 53 verificações, incluindo corpo remoto em primeira pessoa/ADS, respawn, noite, nuvens, todos os tiros físicos, limite de efeitos, números a 20 e 200 metros com FOV 70° e 14°, granada armada/lançada/última carga/morte/explosão na mão.
- Servidor e dois clientes ENet locais: 12 verificações específicas de seleção, arma oculta, corpo completo, relógio, pavio compartilhado, arremesso e morte com granada. Disparo com granada na mão rejeitado na autoridade com arma correta selecionada.
- Regressão de granada, desconexão e retorno: tiro e recarga de FAL e sniper após reconectar. A espera do teste foi corrigida para verificar inventário confirmado, além do contador local que pode zerar antes de chegar a confirmação.
- Transporte com perda: 3.106 datagramas, 253 descartados, atraso 20–70 ms; três processos sem falhas, morte/respawn/recarga/movimento e áudio de morte consistentes.
- Lobby naval 18, física naval 15, combate 86, contato de armas brancas/NPCs 73 e ragdoll 4 verificações aprovadas.
- Teste visual no mundo naval: ciclo de 480 segundos e relógio do mar preservado; número mantém 18 pixels com e sem zoom. Capturas em `work/naval-154-*.png`.

## Publicação

**Publicada em 23/10/2026: versão 1.5.4, build 24**, em http://192.168.101.24/.

- Ativação assinada: `work/update-154-deploy.log`, com `VERIFIED_READY build=24` e `DEPLOYED build=24 version=1.5.4`. O verificador de presença de jogadores foi respeitado.
- Download real, assinatura, instalação, segunda execução sem download, conteúdo do PCK e boot de produção aprovados: `work/update-154-distribution.log` e `tests/ubuntu-distribution-results.json`. Recursos de QA não estão no pacote público.
- Dois executáveis nativos autenticados no Naval: `work/update-154-central-naval.log`. Movimento, disparo, áudio remoto e continuidade após a saída do criador aprovados.
- Dois clientes com renderização no PVP da VM: `work/update-154-central-pvp.log`. Corpo remoto visível em FPP, preparação da granada ocultando/bloqueando a arma, pavio descontado ao lançar e explosão recebida pelos dois clientes, sem falhas.
- Substituição de sessão autenticada e reconexão na VM: `work/update-154-central-reconnect.log`. Sessão anterior volta ao menu, observador mantém os dois jogadores e recebe granada/explosão da sessão nova.
- Bateria visual final: `work/update-154-final-visuals-2.log`, sem erros de script. A fixture de dano naval foi ajustada para não tentar chamar um serviço de contas inexistente no teste local.
- Login e menus no executável final de QA: **44 verificações aprovadas**, incluindo sessão salva, conta correta, logout, timeout e formulário em 1280×800 e 1920×1080: `work/update-154-final-login-native.log` e `tests/login-ui-results.json`.

Todos os participantes precisam atualizar para a mesma versão, pois a sincronização da preparação da granada utiliza novos RPCs.
