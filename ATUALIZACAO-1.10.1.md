# 1.10.1 — Entrada online e novas coberturas

Publicada em 29/10/2026 no Ubuntu, **build 72**. O manifesto, o cliente Windows protegido e o servidor Linux foram atualizados juntos; os quatro serviços estão ativos. O banco de contas foi preservado e copiado antes da ativação. Protocolo BR: 7, Guerra: 30.

## Battle Royale online

Foram identificados dois bloqueios distintos que não apareciam nas fixtures de combate/loot ou na verificação de saúde dos serviços da 1.10.0:

1. O roteador de pareamento tentava registrar uma segunda `MultiplayerAPI` dentro do ramo que já possuía a conexão da partida. Godot rejeita essa configuração. O roteador agora vive num ramo independente, com encerramento e remoção no fim da busca, cancelamento e saída.
2. O broker exportado iniciava as salas com `--main-pack`, embora o runtime protegido proíba substituição de caminhos. Os processos encerravam antes de preparar a sala. A inicialização agora usa o PCK adjacente automaticamente, preservando a proteção do executável.

A espera também passa a mostrar explicitamente seu HUD, mesmo quando a entrada anterior deixou a camada oculta. Falhas de busca e SAIR permanecem visíveis. Regressão pela entrada do menu real: **35 verificações** em headless e 35 em Compatibility/1280×800, incluindo API independente, erro de conta/ticket, cancelamento e ausência de roteadores órfãos.

O artefato Linux assinado foi testado isoladamente na VM antes de ativar: uma sala real, no runtime protegido, carregou mapa/navegação e ficou pronta em aproximadamente sete segundos. Evidência: `work/br72-linux-preflight.json`.

## Personagem, armas e lunetas

- A arma deitada passou a usar a altura dos ombros da pose baixa, em vez do ponto de apoio de um personagem em pé. Isso corrige braços esticados sobre a cabeça. Recarga da AK mantém os alvos das mãos nas posturas baixas.
- A reconstrução da arma atualiza sua apresentação local imediatamente, resolvendo punhos invisíveis e armas que só voltavam a aparecer ao mirar. Cópias destacadas são descartadas com verificação do pai.
- Nos dois dumps recentes do usuário, o crash nativo ocorreu em `Node::remove_child` com pai nulo. Foram protegidas as remoções da apresentação FPP e dos marcadores de acessórios. Regressão no mapa Guerra completo: **319 verificações**, em headless e gráfico, com 20 implantações, 19 respawns, FAL/time 1, AK/time 2, ópticas, FPP/TPP, Javelin/RPG e raízes deliberadamente destacadas. Não houve crash nesse cenário; isso não comprova ausência de falhas em outros caminhos.
- PSO e Prismática são itens/cenas separados; a seleção efetiva foi conferida em FAL e AK, no mundo e na cópia FPP. Ambas continuam com **ampliação 4×**. Como as carcaças herdadas ficavam parecidas, a Prismática ganhou exterior curto e facetado, base elevada e ocular octogonal. A PSO conserva corpo longo e suporte lateral. Referências de montagem, observação, lente e balística foram preservadas.

Testes: `work/prone-weapon-pose-validation.json` (**1.126**), regressão de poses compartilhadas (**2.196**), inventário (**38**), auditoria dos modelos (**26**), ópticas gráficas (**54**) e origem do projétil (**490**). Detalhes em `docs/AUDITORIA-LUNETAS-1.10.0.md`. Capturas: `work/prone-weapon-after.png`, `work/war-team1-spawn-scope-regression.png` e `work/optic-model-*.png`.

## Cobertura e chão do Afegão

- **206 conjuntos** de talude/muro rural baixo e **1.029 tamargueiras**, associados a caminhos, limites de propriedades e áreas jogáveis abertas. Novas cenas reutilizáveis e catálogo da biblioteca acompanham a integração.
- MultiMesh por célula, modelos de folhagem próximos/distantes e alcances por tipo. **108 corpos estáticos agrupam 466 formas**; a colisão dos obstáculos não desaparece com o LOD. Folhagem, capim baixo e pequenas pedras não têm colisão ou sombra própria.
- Capim rasteiro, manchas de pedrinhas curtas e normal/material do chão com detalhe fino próximo e menor brilho. O heightmap não mudou e a Nova Grama experimental continua excluída.
- Os 206 conjuntos bloquearam tiros no teste físico. Navegação preparada atualizada: **339 verificações**, 652 candidatos conectados de spawn/zona, 90 interiores e 43 telhados acessíveis preservados.
- A seleção de centros da zona mantém sua lógica de acessibilidade. Não se garante um obstáculo dentro de todo círculo final arbitrariamente estreito. Não foi executada nova série de benchmarks ou prometido ganho de FPS.

Evidências: `work/afghan-cover-after.json`, `work/br-navigation-validation.json` e capturas pareadas `work/afghan-cover-{before,after}-{0,1,2}.png`. A diretriz permanente do projeto agora explicita LOD, agrupamento, colisão persistente de cobertura e inclusão na navegação como parte da entrega de objetos novos.

## Distribuição

- `work/publication1101-activation.log`: `DEPLOYED build=72 version=1.10.1`.
- `work/publication1101-verified.json`: download HTTPS completo de **208.249.516 bytes**, manifesto aprovado e SHA-256 conferidos, site/histórico, API e quatro serviços saudáveis, PCK Linux correto e backup anterior à atualização.
- `work/signed-install-validation.json`: assinatura real, extração e verificação de EXE/PCK/DLL, instalação reaberta e EXE extraído iniciado por 180 quadros com a biblioteca de voz carregada, sem erros.
- Quem já substituiu o atualizador para a 1.10.0 só precisa fechar o jogo e abri-lo pelo atualizador. Launchers anteriores à inclusão da voz ainda precisam ser substituídos uma vez pelo executável do site.

O teste de entrada online com duas contas reais passou em **18 verificações por cliente**, registrado em `work/ubuntu-br1100-summary.json`. Foram usados HTTPS e DTLS reais, sem atalhos de autenticação ou roteamento: mesma sala na porta 3020, HUD de espera visível, dois humanos e dez bots, contagem fixa de 30 segundos, partida ativa com 12 participantes/100 de vida, inventário privado e zona, saída, voz encerrada e nenhum roteador órfão. RTT observado: 16 e 23 ms. Os clientes de diagnóstico eram headless; este teste não afirma ter testado microfone, decodificação audível, disparos ou coleta nessa sessão. O nome do arquivo é histórico, mas o relatório registra protocolo 7 e execução aprovada após a ativação da build 72.
