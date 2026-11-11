# Olist Analytics — duas versões revisadas

## Dashboard interativo

https://guilherme-molina-portfolio.guilhermemolinasolan.chatgpt.site/olist/

Acesso preservado: privado para o proprietário, como o portfólio. Quatro visões: Visão geral, Logística, Categorias & valor, Fornecedores. Filtros por mês da compra, estado do cliente, categoria e status. Exportação CSV da tabela exibida, com os filtros identificados. O ranking de fornecedores exporta as mesmas até 30 linhas mostradas na interface.

## Power BI Desktop

Abra **powerbi/olist_ecommerce_dashboard.pbix**. O arquivo contém o modelo importado, com os dados já carregados; não depende de um MySQL local para abrir e explorar.

Para atualizar o modelo depois de mover os arquivos: use a pasta **powerbi/data** deste repositório, abra Transformar dados → Gerenciar parâmetros e ajuste **OlistDataPath** para o caminho absoluto da pasta powerbi/data no seu computador. A atualização lê os CSVs dessa pasta; não consulta a operação atual da Olist. Mantenha os arquivos juntos e atualize o parâmetro antes de clicar em Atualizar.

O PBIX foi aberto, salvo e reaberto no Power BI Desktop instalado. As quatro páginas foram verificadas quanto a erros de carregamento. Os principais indicadores e o recorte de clientes de SP foram consultados diretamente no modelo após reabrir o arquivo final.

O arquivo usa o formato de relatório atual do Power BI Desktop e pode exigir uma versão recente do aplicativo.

## O que mudou

- Organização visual em quatro páginas com cabeçalhos, cartões e gráficos maiores.
- Evolução mensal com ordenação cronológica.
- Mapas com geocodificação ambígua substituídos por comparações por estado.
- Estado do cliente usado explicitamente na visão executiva, evitando confusão com o estado do vendedor.
- Matriz financeira usa os valores da própria categoria, sem repetir o total geral em cada linha.
- Médias e taxas de fornecedores não são somadas.
- Pontualidade considera somente entregas confirmadas com datas válidas e compara o dia da entrega com o dia prometido.
- Avaliação usa a última avaliação por pedido, sem multiplicação pelo número de itens.
- Fontes do Power BI convertidas para CSVs portáteis; dados originais preservados no GitHub.
- O portfólio agora abre a demonstração interativa no case Olist.

## Definições e totais de referência

Base: arquivos do repositório MolinaGG/olist-ecommerce-analytics, revisão **cf8524a59b856e684d6538aa3f7c524e15438b43**, dados públicos históricos de 2016–2018. Estudo independente, sem vínculo comercial com a Olist. Meses nas extremidades da base podem estar incompletos.

| Indicador | Definição | Total sem filtros |
|---|---|---:|
| Pedidos | Pedidos distintos com pelo menos um item | 98.666 |
| Valor em produtos | Soma dos preços dos itens, sem frete, em todos os status | R$ 13.591.643,70 |
| Frete | Soma do frete dos itens | R$ 2.251.909,54 |
| Entregas válidas | Status entregue e datas de entrega e previsão presentes | 96.470 |
| Atrasos | Entrega em dia posterior ao prometido | 6.534 |
| Pontualidade | Entregas válidas sem atraso / entregas válidas | 93,2269% |
| Pedidos avaliados | Último registro de avaliação por pedido com itens | 97.917 |
| Avaliação média | Média das últimas notas dos pedidos | 4,10466 / 5 |
| Valor com ocorrência | Itens em pedidos cancelados ou atrasados | R$ 1.081.159,61 |

São excluídos 775 pedidos sem itens. O valor em produtos não é receita contábil reconhecida nem lucro. Atraso ou cancelamento é uma ocorrência operacional: a exposição de valor não comprova perda financeira.

Um pedido pode conter várias categorias ou fornecedores. Os preços dos itens são aditivos entre categorias e fornecedores; as contagens de pedidos dessas linhas não são aditivas.

A nota de um pedido com vários fornecedores é atribuída a cada fornecedor participante, uma vez por combinação fornecedor–pedido. Isso não identifica a responsabilidade individual do vendedor por uma nota ou atraso.

## Diferenças de exploração entre as versões

Na web, todos os gráficos são recalculados com o mesmo recorte. As categorias aparecem com os nomes em português da base. A segmentação de fornecedores muda com os filtros.

No Power BI, as visões agregadas de categorias, logística regional e fornecedores são tabelas de snapshot do período completo. Seus visuais se cruzam dentro da mesma tabela; não devem ser tratados como tabelas dinâmicas por mês. As medidas executivas baseadas em fact_orders respeitam o contexto do modelo. Os nomes de categorias em inglês preservam o mapeamento do modelo original. Os segmentos da dimensão de fornecedores refletem o snapshot completo, não uma nova classificação a cada filtro.

## Tema e referências

**powerbi/theme.json** é o tema de cores e tipografia do relatório. Sua aplicação já está incluída no PBIX.

- [Projeto e dados originais](https://github.com/MolinaGG/olist-ecommerce-analytics/tree/cf8524a59b856e684d6538aa3f7c524e15438b43)
- [Documentação Microsoft: temas de relatório](https://learn.microsoft.com/en-us/power-bi/create-reports/desktop-report-themes)
- [Documentação Microsoft: pastas de relatório e PBIR](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-report)
