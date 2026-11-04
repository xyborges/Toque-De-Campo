# Atualização 1.13.1 — Explosões e áudio de combate

**Estado: PUBLICADA em 04/11/2026 — build 87.** Build anterior em produção: 85 / 1.13.0.

## Conteúdo

- Novo pacote de sons V3 para explosões de tanques, perto e distante, com cinco estalos de munição dentro dos próprios WAVs.
- Sincronização de clarões e detonações secundárias visuais para tanques e outros blindados.
- Explosões pesadas mais presentes a curta distância, incluindo correção do teto de áudio dos emissores e da carcaça que abafava a própria explosão.
- Bola de fogo maior, fumaça, poeira, onda de choque e efeitos controlados por pools.
- Granadas e drones mantêm suas amostras específicas.
- A mixagem dinâmica global entre explosões e armas ainda não foi implementada. Está documentada em docs/PLANO-MESTRE-AUDIO-20261104.md.

## Verificações

- Publicador oficial: VERIFIED_READY build=87 e DEPLOYED build=87 version=1.13.1, código zero.
- Pré-verificação: PREFLIGHT_OK build=87, publicado anteriormente build=85.
- Instalação assinada em QA: 13 verificações, nenhuma falha; executável protegido inicia e carrega o codec de voz.
- Ucrânia: preparado v14 pelo pipeline oficial; integridade e identidade de mapas aprovadas.
- Integração de sons V3: 20 verificações; pacote de explosões e estresse de efeitos sem falhas.
- Pós-publicação: manifesto público HTTPS exatamente igual ao assinado local, versão 1.13.1/build 87.
- Servidor Linux: /opt/toque-de-campo/releases/build-87 ativo, hashes dos binários correspondentes ao manifesto e cinco serviços ativos.

## Limites conhecidos

O lançamento não incluiu teste longo com dois clientes exportados em partida multiplayer completa ou benchmark de 60 FPS com 28 bots. Uma suíte anterior de 28 bots acusou falhas de expectativas de objetivos e placar, que não foram apresentadas como resolvidas. Os testes de inicialização, recursos, assinatura, publicação e serviços não equivalem a aprovação completa de multiplayer e desempenho.

Endereço interno do download: https://192.168.101.24/

Verificador pós-publicação: work/verify_release1131_live.py.
