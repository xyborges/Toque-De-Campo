# 1.9.3 — Guerra offline, posturas e desempenho

Estado: publicada no Ubuntu em 27/10/2026, versão 1.9.3, build 65. Cliente, servidor, site e manifesto de atualização foram ativados juntos.

## Jogabilidade

- Guerra offline: 18 participantes por padrão (um jogador e 17 bots), nove por equipe. A seleção inicial permite 12 ou 18; a capacidade online continua em 12.
- Grupos escolhem objetivos conforme controle, distância e distribuição dos outros grupos. A infantaria concentra o combate na frente central; a equipe de transporte pode seguir para os portos.
- Bots utilizam os assentos e controles reais dos blindados, incluindo passageiros, recarga e abandono de uma rota bloqueada. A reserva inicial deixa os blindados aliados disponíveis para o jogador.
- Rajadas com pausas, reação e erro deliberado, sem aquisição de inimigos através de paredes. A seleção de alvos considera o peito real, inclusive em posturas baixas. Cadência e consumo de munição usam a autoridade existente.
- Ctrl mantém o agachamento. Z alterna entre deitar e levantar. Joelhos articulados, botas, roupa, câmera, arma e regiões de acerto acompanham as posturas. O corpo não é achatado por escala vertical.
- A verificação de espaço impede levantar sob um teto. Todas as posturas compartilham o mesmo plano de apoio; deitar e encostar no chão não impede voltar a levantar.
- Projéteis de tanque e 30 mm conservam a velocidade inicial e perdem velocidade progressivamente depois do trecho próximo. A integração compartilhada continua aplicando gravidade; a queda é maior quando comparada na mesma distância.

## Correções e redução de trabalho

- Projeção de velocidade sobre uma subida deixa de ser reaplicada como impulso vertical no quadro seguinte. O auxílio de degraus só faz as verificações adicionais quando o movimento realmente encontra uma borda.
- Personagens remotos usam atualizações de pose por distância. Posição e combate continuam na simulação; personagens e cobertura não desaparecem para economizar desenho.
- Blindados parados podem conservar o apoio validado mesmo ocupados; direção, mudanças de apoio e geometria invalidam esse repouso. Torre e recarga continuam sendo atualizadas.
- Grama usa setores visuais maiores e não projeta sombras pequenas. Árvores mantêm os seis volumes da copa no LOD distante; a grama possui uma versão distante opaca. Árvores e colisões continuam presentes.
- O mapa tático reutiliza a textura do território durante mudanças de porcentagem da captura. Os pixels só são refeitos quando o estado visual do território muda; o marcador mantém sua atualização normal.
- O ragdoll preserva as canelas articuladas e as botas. A cena `modes/war/scenes/east_port.tscn`, editada pelo usuário, permanece intacta.
- A autoridade reconstrói a arma escolhida também para personagens remotos e bots reaparecendo. Ela não conserva o modelo/cano inicial da AK após uma implantação com FAL.

## Validação

- `tests/offline193.gd`: posturas, apoio real no chão, espaço sob teto, câmera, boca do cano, regiões de acerto, queda por distância, subida e ragdoll. Acrescentada travessia de degraus e reutilização do mapa tático.
- `tests/mobility191.gd`: 353 verificações, 88 cenários com Guarani, BMP-2, Abrams e T-90. A comparação Jolt passou após configurar recuperação completa das sobreposições; os limites dos testes foram mantidos.
- `tests/ragdoll_stability.gd` e `tests/ragdoll_contact_stress.gd`: estabilidade e contato de 12 corpos, sem falhas na cópia Jolt.
- `tests/offline193_ai.gd`: partida completa de 160 segundos, 18 participantes, veículos, capturas, dano e mortes. Execução em tempo real: 819 disparos aceitos, 37 recargas, 14 mortes e nenhuma rejeição de tiro. Essa execução funcional não mede FPS.
- `tests/run_review192_transition.py --project work/physics193`: dois clientes reais com DTLS, troca Deserto → Guerra, APC, FAL, Glock, postura replicada, Stinger, morte deitado e implantação. 32 verificações passaram.
- Após a publicação, `tests/run_ubuntu_review192.py --protocol 25 --label release193`: duas contas conectadas ao Ubuntu por DTLS, 21 verificações sem falhas. FAL/AK automáticas, recargas de fuzil e Glock nos dois times, drone, morte real por granada, implantação após oito segundos, respawn na base, disparo e saída do APC.
- Download HTTPS real: manifesto publicado idêntico ao assinado localmente, instalador idêntico, instalação 1.9.3 concluída e segunda verificação sem novo download. Cinco verificações de proteção do pacote passaram; inicialização do executável exportado sem erros. Os três serviços de jogo permaneceram ativos e o site exibe as notas da 1.9.3.

## Física e desempenho

A versão utiliza Jolt integrado ao Godot, com recuperação completa das sobreposições nas consultas de movimento. O teste comparativo do mesmo cenário com 18 participantes a 1920 × 1080 passou de 25,3 para 51,0 FPS médios; 1% low de 6,0 para 25,3 FPS e pior quadro de 190,3 para 61,0 ms. As decisões dos bots variam entre execuções. Isso representa melhora medida, mas ainda não cumpre 60 FPS estáveis. Consulte `BENCHMARK-1.9.3.md` para escopo e limitações.

As sugestões externas de otimização foram tratadas como referências. O jogo já usa Compatibility, instanciamento, agrupamento de detalhes, pooling e LOD. Não foi aplicado um preset que remova cobertura e revele inimigos.

Na conferência de produção, o RTT ENet medido com DTLS foi de 21,84 ms e 23,04 ms em média nos dois clientes (máximos de 24 e 26 ms). Esses clientes estavam sem renderização e essa medida descreve apenas esta conexão; não é um benchmark gráfico nem uma comparação com transporte sem criptografia.
