# Estudo de caso: desempenho de entregas como problema de BI

[English](CASE_STUDY.md) · [Dashboard](https://guilherme-molina-portfolio.guilhermemolinasolan.chatgpt.site/olist/) · [Projeto](../README.pt-BR.md)

## Problema e público

Uma pessoa de operações ou finanças precisa distinguir sinais de desempenho das entregas do valor monetário associado aos pedidos. A pergunta é onde investigar, não quanto dinheiro foi definitivamente perdido.

## Dados e método

A base pública Olist cobre 2016–2018. O pipeline revisado usa Python para preparar os snapshots web e Power BI. O SQL original permanece como implementação histórica separada.

Pedidos podem ter vários itens, categorias e fornecedores. Valores por item são aditivos; contagens de pedidos entre categorias não são. As avaliações usam o último registro por pedido. A pontualidade usa entregas confirmadas com datas válidas e compara dias de calendário. Isso evita dar peso extra a pedidos com vários itens.

## Resultados e interpretação

A referência documentada tem 98.666 pedidos com itens. Entre 96.470 entregas válidas, 6.534 atrasaram: 93,2269% de pontualidade. O valor dos produtos totaliza R$ 13.591.643,70, sem frete. Esses números descrevem a base, não resultados gerados para clientes.

As visões por região, categoria e fornecedor apoiam a priorização de investigações. Comparações exigem atenção ao tamanho da amostra e ao denominador. Uma avaliação compartilhada por vários fornecedores do mesmo pedido não identifica a responsabilidade individual pelo problema.

## Evidências verificáveis

- [Preparação e exclusões](../scripts/build_dashboard_data.py).
- [Dados do Power BI](../scripts/build_powerbi_data.py).
- [Lógica de agregação](../dashboard/metrics.js).
- [Verificações de granularidade, filtros e totais](../tests/metrics.test.cjs).
- [Definições e limitações do Power BI](METHODOLOGY.md).

## Limitações e discussão da contribuição

Estudo independente com dados históricos. Não comprova contratação pela Olist, economia operacional, receita reconhecida, lucro ou causalidade. Os snapshots agregados do Power BI não recalculam todos os recortes mensais como a versão web.

Em uma entrevista, o percurso útil vai do CSV ao indicador: unidade de análise, exclusões, denominador, validação e escolhas técnicas. O histórico do repositório apoia a discussão da implementação; uma captura de tela não comprova autoria pessoal nem independência de assistência por IA.
