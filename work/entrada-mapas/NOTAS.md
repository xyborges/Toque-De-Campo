# Entrada/mapas — notas IA 2
Base: main ee969af + cache de lotes 2c71a80. Godot 4.7.2. Branch ia2/entrada-mapas-integral-20261107. Main, serviço e launcher preservados.
1/Perfil (TDC_IA2_MAP_STAGES=1, só diagnóstico): 3 coletas com cache ON e geometria idêntica. Bairros 1.204–1.213 ms; encostas 953–962 ms; 225 tiles 575–579 ms; landmarks/fiação/clutter 474–487 ms. Subperfil bairros: casas 1.038 ms, comércio 191 ms e alturas 87 ms (escopos inclusivos). Decisão: top 3 bairros, encostas e terreno; encostas são frente paralela. Commit: 1076dff.
1A/Box headless (TDC_IA2_FAST_HEADLESS_BOX=1, padrão OFF): A/A 2, cinco pares A/B; mundo A 4.175,4 → B 4.090,7 ms (-2,03%, ruído A 5,83%, 4/5 pares), bairros -9,82% (ruído 11,28%). Geometria e raycasts idênticos; GPU R0I 33 °C, estado 0x1 (idle), sem evidência de limite térmico. Decisão: DESCARTAR; EnvironmentKit restaurado, patch gzip arquivado. Commit: pendente.
1B/Terreno: por medir; testar cache assinado de malhas físicas das 225 tiles, flag independente.
2/Cache para revisões: main ee969af já validada; v25 7717aa5 e Afeganistão por auditar.
3/Cache frio x aquecido: por medir.
4/Cliente gráfico real: por medir.
5/Segundo cliente em partida: por medir.
6/Combinado 5 pares/mapa, 60 s: por medir.
7/Regressões: por medir.
