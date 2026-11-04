# Extended look — implementação Godot 1.5.0

Data: 23/10/2026. Base: 1.4.1, build 18. Nova versão publicada: **1.5.0, build 19**. Este relatório registra o trabalho realizado; a validação da publicação aparece ao final.

## Resultado

- **Escritório:** salão original preservado, 480 m² de anexo conectado, recepção, administração, arquivo, manutenção e corredor de serviço. Estruturas de estantes, mobiliário, dutos, vigas, iluminação, sinalização e materiais detalhados.
- **Deserto:** terreno físico de 300 × 300 m, dunas navegáveis, posto atravessável, janelas abertas, comunicações, logística, manutenção, guaritas e múltiplas aproximações. O PVP continua individual, de dois a seis jogadores.
- **Naval:** cinco ilhas com farol, radar, costa selvagem, fortificação e porto; oceano, nuvens, iluminação noturna e luzes de posição. Os limites de navegação, equações das ondas, flutuação e balística permanecem.
- **Câmera:** colisão por esfera varrida, recuo imediato ao encontrar sólidos e retorno suave. Protege paredes, portas fechadas, armários, teto e chão; também aplicada à câmera naval. Muito perto do corpo, usa a apresentação FPP sem mudar a escolha TPP, o cano físico ou o estado multiplayer.

Descrição detalhada da planta, objetos e regras em [MAPAS-ESTADO-ATUAL.md](MAPAS-ESTADO-ATUAL.md). [Galeria de comparação](EXTENDED-LOOK-COMPARACAO.html): nove pares de capturas da própria engine, com mesmas posições, alvos, FOV e resolução, além de vistas dos cômodos, instalações, noite e câmera. Não são imagens geradas ou retocadas.

## Método e preservação

Inspeção inicial de construção dos mundos, colisões de projéteis, navegação de NPCs e iluminação. Código original e levantamento preservados em `work/extended-look-before/`. Escritório implementado e testado antes do deserto; deserto validado antes do naval. Câmera tratada ao final, conforme o pedido adicional.

Nenhuma alteração no serviço de contas, esquema de salvamento, valores das armas ou regras de dano. Os novos materiais e objetos não substituem mapas por fundos. Os testes de rede usam contas e diretórios isolados.

A alteração de terreno exige clientes atualizados: o PVP valida revisão do mapa e o naval passou ao protocolo 4, para impedir partidas entre construções com colisões diferentes.

## Geometria e materiais

Os modelos ambientais são módulos originais de geometria: estantes estruturadas, mesas e cadeiras com encosto/rodízios, caixas etiquetadas, pallets, tubos, antenas treliçadas, gerador, contêineres corrugados e caminhão estático. Nas ilhas: torre de farol, antena parabólica, bunker com aberturas, armazém, cais, guindaste e rochas irregulares.

Onze famílias de materiais: concreto, reboco, aço, madeira, papelão, areia, rocha, tecido, piso, asfalto e tijolo. Cada uma possui albedo, rugosidade e normal: **33 texturas próprias de 256 × 256 pixels**, aproximadamente 2,27 MB em PNG. Criadas deterministicamente em `tools/generate_environment_textures.py`; autoria/proveniência em `assets/environment/README.txt`. Não foi necessário baixar modelos ou texturas externos. Licenças dos modelos de armas, fotografias e músicas anteriores permanecem independentes.

### Sólidos e decoração

- Terreno, paredes, móveis grandes, caixas, grandes rochas e instalações possuem colisores.
- Portas e janelas abertas são vazios físicos; não apenas placas escuras na parede.
- Servidor e cliente constroem as mesmas colisões, incluindo a parábola do radar.
- Etiquetas, papéis, fios finos, plantas e microdetalhes não bloqueiam disparos como paredes invisíveis.
- As alturas de spawn e navegação do deserto usam a mesma triangulação do terreno visível e físico.
- Fundo oceânico físico, encostas e rochas submersas foram preparados. **Mergulho jogável não foi implementado.**

## Otimização

Materiais e primitivas compartilhados, MultiMesh por material/setor, LOD geométrico para rochas, alcance de microdetalhes limitado a 70 m, sombras seletivas, poeira limitada e oclusores somente nas paredes fechadas do escritório. As aberturas não recebem oclusores sólidos. Servidores dedicados constroem as colisões sem decoração gráfica.

### Medição real neste PC

GTX 1650, OpenGL, janela de 1280 × 800, teto de 60 FPS. Aquecimento de 4,5 s e amostra de 5 s por cenário, NPCs ativos. Valores não demonstram desempenho em outros PCs ou estabilidade por horas.

| Mapa | NPCs | FPS médio | Tempo de frame P95 | Física média | Memória de vídeo medida |
|---|---:|---:|---:|---:|---:|
| Escritório | 16 | 60,0 | 17,27 ms | 2,76 ms | 54,17 MiB |
| Deserto | 24 | 60,0 | 17,77 ms | 7,28 ms | 60,79 MiB |

As métricas das capturas estáticas ficam em `tests/screens/extended-look/{before,after}/*-metrics.json`. Os valores de FPS dessas capturas curtas não substituem a amostra com combate acima. Aumento de triângulos era esperado; instanciamento e oclusão evitam transformar cada detalhe numa chamada independente.

## Correções encontradas durante a validação

1. **Spawn inicial online:** o cliente não aplicava a posição autorizada pelo servidor. Agora aplica uma vez; confirmação duplicada não teleporta novamente.
2. **Avatar após desconexão:** um snapshot não confiável atrasado recriava um jogador já removido pelo evento confiável. Apenas o evento de entrada cria avatares; snapshots de IDs desconhecidos são descartados.
3. **Malhas rotacionadas:** escala aplicada nos eixos globais deformava alguns módulos. Escala agora compõe a base local.
4. **LOD:** duplicar MultiMesh preenchido causava diagnóstico de tamanho de buffer em headless. O nível distante cria buffers próprios e copia as transformações.
5. **Terreno:** corrigido o sentido dos triângulos para manter a face renderizada para cima e a consulta física consistente.
6. **Teste de seis clientes:** o servidor do teste encerrava antes de clientes atrasados concluírem sua janela de observação. A fixture passou a aguardar os relatórios recentes dos seis; as exigências de combate, quatro armas e replicação continuam iguais.
7. **Teste de recompensa:** expectativa antiga de 30.030 moedas atualizada para 30, respeitando a remoção anterior do bônus inicial de 30 mil. O valor de produção não foi alterado.

## Testes executados

| Teste | Resultado e evidência |
|---|---|
| `tests/environment_office.gd` | 11 verificações: quatro rotas de salas, passagem traseira, sólidos, spawn e cápsula real atravessando a porta |
| `tests/environment_desert.gd` | 17: terreno físico, alturas, portas/paredes, rotas de NPC, oito spawns livres, locomoção distante, posição inicial autorizada e snapshot atrasado |
| `tests/environment_naval.gd` | 19: colisores idênticos servidor/cliente, cinco ilhas físicas, spawn seguro, fundo, noite e impacto previsto versus real das quatro armas com movimento |
| `tests/camera_collision.gd` | 16, em janela real: porta, armário, teto/chão, recuo/retorno, olhos FPP/mira preservados, retorno TPP, superfície e obstáculo naval |
| Regressões gerais | 196: lobby 18, física naval 15, combate 86, armas brancas/NPCs 73, ragdoll 4 |
| `tests/naval_weapon_switch.gd` | 19, dois clientes ENet em janela: quatro armas, troca segurando gatilho, mensagens atrasadas, soltura, sem disparo vazio, recarga e pausa |
| `tests/run_network_tests.py` | Servidor + dois clientes, 20–70 ms e cerca de 8% de perda: três disparos confirmados, dano/morte/respawn, recarga, inventário, áudio de morte igual, reconexão sem duplicação, recompensa única |
| `tests/run_naval_network.py` | Multiplayer com 5% de perda e 20–65 ms: dano, morte, respawn, entrada tardia e transferência de dono |
| `tests/run_naval_six.py` | Servidor e seis clientes: todos observaram seis navios, mais de 130 atualizações e eventos das quatro armas, sem falhas |
| Inspeção do pacote Windows | Materiais, scripts ambientais, shaders, músicas e tema presentes; cena QA ausente do pacote de produção |

Os relatórios JSON estão em `tests/`; logs finais em `work/`. A validação gráfica mostrou avisos preexistentes de atlas de textura ao encerrar o renderizador OpenGL; não foi feito um ensaio prolongado de memória. No teste nativo de troca de armas, o dispositivo WASAPI foi invalidado pelo sistema após as verificações; as 19 verificações passaram, mas isso não equivale a medir a qualidade de áudio por horas.

## Arquivos adicionados

- `scripts/environment/environment_kit.gd`: materiais, módulos, colisores, instanciamento e LOD.
- `scripts/environment/environment_props.gd`: objetos compartilhados.
- `scripts/environment/environment_atmosphere.gd`: vento e poeira.
- `scripts/environment/office_map.gd`: complexo industrial.
- `scripts/environment/desert_terrain.gd`: relevo físico e consultas de altura.
- `scripts/environment/desert_map.gd`: posto e setores.
- `scripts/environment/naval_islands.gd`: ilhas, construções e fundo.
- `scripts/camera_obstruction.gd`: colisão volumétrica compartilhada.
- `modes/naval/shaders/ocean.gdshader` e `clouds.gdshader`.
- `assets/environment/materials/*.png`, `assets/environment/README.txt`.
- `tools/generate_environment_textures.py`, `tools/build_environment_report.py`.
- Testes de ambiente/câmera/captura/desempenho e seus relatórios.

## Arquivos principais alterados

- `scripts/main.gd`: construção dos mapas, iluminação, spawn, validação de altura/revisão e criação confiável de avatares.
- `scripts/offline_director.gd`: navegação, terreno, limites e spawn.
- `scripts/player.gd`: limites do terreno e câmera com colisão.
- `modes/naval/scripts/world.gd`: ambiente naval, céu e iluminação.
- `modes/naval/scripts/camera.gd`, `mode.gd`: câmera segura.
- `modes/naval/scripts/ship.gd`: luzes de posição.
- `modes/naval/scripts/catalog.gd`: protocolo de compatibilidade.
- `tests/network_combat.gd`, `tests/naval_six.gd`: regressões alinhadas ao estado atual e coordenação de término.
- `distribution/ubuntu/publish_ubuntu.py`: versão da publicação.
- Documentação: este relatório, descrição atual dos mapas, galeria, `LEIA-ME.md` e `SERVIDOR-UBUNTU.md`.

## Publicação e validação no Ubuntu

**1.5.0, build 19, publicada em http://192.168.101.24/**. Pacote de aproximadamente 62,6 MB, manifesto assinado e troca atômica da versão do servidor. O verificador de implantação confirmou que não havia jogadores impedindo a atualização; não foi necessário encerrar partidas humanas. Contas e saldos preservados.

Testes posteriores à publicação:

- Dois executáveis QA Windows exportados conectaram contas reais isoladas ao servidor central naval: movimento, disparo, áudio remoto e permanência da sala após o criador sair. Ambos terminaram sem falhas.
- Dois clientes gráficos no PVP Deserto: contas carregadas, dois jogadores reais sem avatar fantasma de servidor, arma inicial e disparo autorizado replicados. Ambos sem falhas.
- Login nativo exportado: **44 verificações**, incluindo sessão persistente validada no servidor, expiração, login/registro, logout, navegação e tamanhos de 800 × 600 a 1920 × 1080. Sem falhas.
- Regressão gráfica de menus: seis verificações aprovadas; Ver embarcações permanece na loja, opções não redirecionam para salas e logout mantém a mesma música avançando.
- Download real da VM: hash do executável conferido, manifesto igual ao publicado, instalação pelo atualizador e segunda execução sem novo download. Inicialização do executável de produção aprovada.
- HTTPS da API validado com a CA do projeto; caminhos privados continuam inacessíveis por HTTP. Pacote de produção contém os novos materiais/shaders/scripts e não contém a cena de QA.

Evidências: `work/environment-release-deploy.log`, `work/environment-ubuntu-naval.log`, `work/environment-ubuntu-pvp.log`, `work/environment-login-native.log`, `work/environment-ubuntu-distribution.log` e relatórios correspondentes em `tests/`.

Para receber a atualização, feche o jogo e abra o atualizador. Todos os participantes precisam da versão nova, pois as colisões dos mapas mudaram. Nenhum endereço ou porta precisa ser digitado no fluxo normal do jogo.

### Complemento — build 20

Site e instalador receberam a lista das novidades da 1.5.0 em cinco tópicos, com a mesma fonte `distribution/release-notes.json`. As notas são assinadas junto ao manifesto do jogo. A interface do instalador foi ampliada, possui área de novidades com rolagem e permanece aberta até o jogador clicar em Jogar. A página de download foi reorganizada com cartões das mudanças e instruções atuais. Download real e ausência de novo download foram novamente conferidos no build 20; não houve alteração adicional no gameplay. Registro: `work/release-notes-distribution.log`.
