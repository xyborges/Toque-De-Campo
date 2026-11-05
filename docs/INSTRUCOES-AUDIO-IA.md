# Instruções para criação de áudio com IA

Este guia orienta futuras tarefas de criação ou edição de áudio para o jogo. Ele não autoriza gerar, importar ou substituir áudio quando o pedido do usuário for somente análise, planejamento ou orientação.

## 1. Entenda o evento antes de gerar

- Inspecione os sons, scripts, buses e regras de reprodução já usados pelo evento e pelo modo de jogo. Identifique se distância, direção, propagação, oclusão, reverberação, impactos, rajadas e caudas já são produzidos pelo jogo.
- Gere somente o conteúdo solicitado. Para uma arma de fogo, o padrão é um disparo individual por arquivo; a cadência e a rajada pertencem ao jogo.
- Preserve a identidade da arma entre variações. Não substitua uma diferença de mixagem por outra arma, outro calibre ou outro evento sonoro.
- Prefira um arquivo de fonte próximo, limpo e consistente quando o mixer já cuidar do som distante. Crie uma gravação distante separada apenas quando ela trouxer uma característica que o sistema do jogo não consiga reproduzir bem.

## 2. Separe o áudio da simulação do jogo

- Não inclua posicionamento estéreo, panorama, Doppler, atraso de propagação, filtro de parede, eco de sala ou reverberação ambiente se o jogo já aplicar esses efeitos.
- Não misture impacto, ricochete, passagem supersônica, cápsula caindo, vento, voz ou outros eventos no arquivo de disparo, a menos que o usuário peça explicitamente e a arquitetura do jogo não os reproduza separadamente.
- Não entregue uma rajada pronta quando cada projétil e impacto são eventos individuais do jogo: ela produziria tiros, impactos ou sincronização fantasmas.
- Se o pedido exigir uma ambiência ou reverberação gravada, explique por que ela deve ficar embutida e confirme que não será duplicada pelo mixer.

## 3. Faça variantes que possam transicionar

- Versões próxima, média e distante devem representar o mesmo evento e manter ataque, identidade, duração útil e cauda compatíveis.
- Para uma versão distante, reduza brilho e presença de modo gradual; não apague o ataque nem invente outro transiente. Deixe atenuação e filtragem contínuas para o áudio 3D do jogo sempre que possível.
- Se o jogo precisar alternar ou misturar versões, alinhe o início do transiente e a região de sobreposição. Combine o nível percebido das versões e proponha uma faixa de transição, evitando limiares com troca abrupta.
- Variações para tiros repetidos podem ter mudanças pequenas de timbre e pitch. Mantenha ataque e volume percebido consistentes; não faça cada tiro soar como uma arma diferente.
- Não prometa alinhamento de fase perfeito em áudio gerado. Confira ataques, cancelamentos, cliques e o resultado da transição numa sessão A/B.

## 4. Formato e acabamento

- Use WAV PCM mono para fontes posicionais de disparo, salvo se o projeto ou o pedido definir outro formato. Para este projeto, prefira 48 kHz; 16 bits é o formato padrão compatível com os kits de combate existentes. Preserve um original em maior resolução quando a ferramenta o produzir, convertendo somente a cópia de integração.
- Comece o arquivo junto ao ataque, sem silêncio inicial desnecessário. Preserve a cauda completa e evite cortes abruptos, clipping, DC offset, ruído digital e compressão/limitação excessiva.
- Não force o mesmo pico em todos os sons. Compare loudness/RMS em condições equivalentes e mantenha headroom; informe duração, taxa de amostragem, canais, profundidade, pico e loudness medido.
- Use nomes estáveis e descritivos, sem espaços ou acentos, seguindo o catálogo existente. Não sobrescreva o áudio original; crie um novo nome ou preserve o arquivo anterior para comparação.

## 5. Prompt-base para gerador de áudio

Adapte os campos entre colchetes ao evento real e às referências autorizadas:

> Crie [quantidade] arquivo(s) de áudio de [evento e arma], um evento isolado por arquivo. Mantenha a mesma identidade sonora em todas as versões. O ataque começa no início do arquivo, sem silêncio inicial, e a cauda termina naturalmente. Gere uma versão [próxima/distante] apenas se ela representar o mesmo evento com uma mudança de perspectiva acústica; preserve o ataque e a duração útil para permitir uma transição gradual. Não inclua rajada, impacto, ricochete, bala passando, cápsula, voz, vento, panorama estéreo, atraso, Doppler, eco ou reverberação de ambiente. Não acrescente compressão ou limitação fortes. Entregue WAV PCM mono, 48 kHz, com volume percebido comparável entre variantes e sem clipping. Informe duração, canais, profundidade, pico e loudness medido. Use somente as referências fornecidas ou autorizadas e registre sua origem.

O prompt não substitui a revisão do arquivo: compare cada resultado com o áudio existente e descarte variações que mudem a arma, acrescentem eventos ou não transicionem sem salto audível.

## 6. Integração e validação no jogo

- Mantenha a reprodução client-side, os limites dos pools e dos raycasts, a configuração de volume do jogador e os buses já usados pelo jogo. Não altere dano, cadência, física, rede ou eventos de combate para acomodar uma gravação.
- Registre o arquivo de origem, ferramenta/modelo, prompt, licença ou autorização de uso e qualquer conversão aplicada. Não use material de referência sem autorização compatível.
- Antes de substituir uma gravação, compare original e candidata no jogo. Avalie perto, transição e longe; fonte à frente, ao lado e atrás; som livre e ocluído; e disparos sobrepostos.
- Verifique que não há silêncio, clique, clipping, corte de cauda, salto de volume, troca de identidade, perda de localização ou evento duplicado. A importação pelo motor, sozinha, não comprova qualidade acústica.
- Atualize catálogo, metadados de importação e verificações automatizadas pertinentes. Não publique nem substitua assets de produção sem a revisão e validação exigidas pelo fluxo Git do projeto.
