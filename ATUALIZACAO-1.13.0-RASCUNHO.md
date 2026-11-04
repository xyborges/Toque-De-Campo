# Atualização 1.13.0 — RASCUNHO DE LANÇAMENTO

**Estado:** candidata local em consolidação; **NÃO PUBLICADA**.
**Base:** versão 1.12.0, build 84, pacote produzido em 03/11/2026 às 17h08.

## Notas para jogadores

**Arsenal modular, explosões e combates renovados**

Novas lunetas 4× e 8× para os fuzis, G3 no modo Guerra, melhorias na IA e no HUD, explosões mais expressivas e maior variedade de abrigos e loot no Afeganistão.

### Miras modulares em todos os fuzis
AK, FAL, G3 e Sniper passam a aceitar Prismática 4×, PSO 4×, Hensoldt ZF 4×24 e Telescópica 8×. A Sniper pode ser usada apenas com mira de ferro e nenhuma luneta é obrigatória.

### Novo fuzil G3
O G3 entra como arma principal padrão da Rússia na Ucrânia e dos Mujahidins no Afeganistão, com carregador de 20 cartuchos, animação de recarga e sons de disparo próximo e distante.

### Explosões e propagação sonora
Novo conjunto de sons para granadas, tanques e drones, amostras próximas e distantes, propagação espacial ao ar livre e efeitos visuais maiores com fumaça persistente, explosões secundárias visuais e ondas de choque.

### Bots mais táticos
IA do modo Guerra melhora seleção de alvos, defesa de objetivos, emprego de lançadores e armas de blindados, granadas e recuperação de veículos presos. O limite atual continua em 28 bots; 57 permanece um objetivo futuro.

### Mais coberturas no Deserto Afegão
Novos abrigos rurais, muros de pátio e detalhes ambientais complementam as construções existentes, com colisões, cobertura e navegação adaptadas.

### Battle Royale menos repetitivo
Nova variação das sementes de partida melhora a alternância dos spawns sem mover os pontos autorais. Doze abrigos recebem novos locais de saque, preservando os pontos anteriores.

### Menus e HUD unificados
Botões e informações de partida passam a usar componentes de interface compartilhados, com navegação de volta e ESC mais consistente, ajustes de inventário em telas menores e melhorias no placar.

### Uniformes aprimorados
Mangas e detalhes dos combatentes afegãos acompanham melhor as articulações do personagem, preservando a identidade visual cartunesca.

## Correções

### Sniper sem luneta fixa
A arma recebe mira de ferro própria, montagem correta das lunetas opcionais, ajustes de ADS e correção da pose do braço ao mirar deitado.

### Navegação e loot dos novos abrigos
A navegação do Battle Royale foi reconstruída e validada para os doze novos abrigos, com rotas de entrada e pontos de loot alcançáveis.

### Inventário e navegação
Corrigidos o fechamento do inventário e o retorno às telas de origem em rotas dos menus e configurações.

## Auditoria de integração (não divulgar como notas públicas)

- 98 arquivos de código/recursos com data posterior à criação da build 84, excluindo importações, UID e dados preparados; não são 98 funcionalidades novas.
- Mapas: Afeganistão v10, Ucrânia v13, Deserto, Escritório e Naval READY.
- Provas atuais: identidade dos mapas PASS; G3 PASS; preferências de miras PASS; Battle Royale UI 41/41; HUD de classes 52/52 após adaptar fixture à G3, sem alterar jogabilidade; kit de explosões 33/33 com renderizador nativo.
- Testes anteriores documentados: ópticas universais 294/294, postura deitado 1126/1126, navegação BR v13 341/341, integridade dos mapas preparados 11/11, menus GUI 34/34, placar 54/54.
- Não há diretório .git no projeto e o Git não foi encontrado no PATH.

## Bloqueios antes da publicação

1. Guerra e BR online: os erros anteriores de admissão de versão dos mapas foram tratados com a reconstrução e preflight, porém falta repetir um ciclo multiplayer com dois clientes exportados.
2. Desempenho: faltam medições completas a 1080p na GTX 1650 com 28 bots após todas as alterações; não afirmar 60 FPS.
3. Exportações locais Windows e Linux já preparadas como build 85, com 10 artefatos assinados e hashes correspondentes. O teste QA externo do cliente protegido expirou sem relatório; a inicialização simples passou. É necessário verificar partida real e versão idêntica cliente/servidor antes de ativar.
4. Revisar encerramento de recursos Jolt, voz em clientes completos e fullscreen/renderizador.

## Controle

O projeto local (project.godot) e distribution/release-notes.json já estão na 1.13.0. As builds Windows e Linux foram exportadas em modo --prepare-only e assinadas como build 85. O Ubuntu segue publicado na 1.12.0/build 84. O preflight remoto passou (85 > 84), mas nenhum upload nem ativação ocorreu. Um teste de inicialização protegida do executável Windows passou; o teste externo completo expirou sem gerar relatório.
