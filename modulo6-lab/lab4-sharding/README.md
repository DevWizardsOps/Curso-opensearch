# Lab 4 — Oversharding

## Objetivo

Observar o impacto de configurações excessivas de shards no OpenSearch e entender como o **oversharding** degrada a performance do cluster.

## Conceitos

### O que é um Shard?

Um **shard** é a unidade básica de divisão de um índice no OpenSearch. Cada índice é dividido em um ou mais shards primários, e cada shard é uma instância independente do Apache Lucene. Shards permitem:

- **Distribuição de dados** entre múltiplos nós
- **Paralelismo** em operações de busca e indexação
- **Escalabilidade horizontal** do cluster

### O que é Oversharding?

**Oversharding** ocorre quando um índice possui mais shards do que o necessário para o volume de dados e o número de nós disponíveis. Consequências:

- **Overhead de coordenação**: cada query precisa ser enviada a todos os shards e os resultados precisam ser mesclados
- **Consumo excessivo de memória heap**: cada shard consome memória no nó (metadados, buffers, etc.)
- **Degradação de performance**: para datasets pequenos, 1 shard é mais eficiente que 20 shards
- **Custo de rebalanceamento**: mais shards = mais movimentação de dados ao adicionar/remover nós

### Regra Geral

- **Tamanho ideal por shard**: entre 10 GB e 50 GB
- **Número de shards**: `ceil(tamanho_total / tamanho_ideal_por_shard)`
- Para datasets pequenos (< 1 GB): **1 shard é suficiente**

## Pré-requisitos

- Variáveis de ambiente configuradas (feito no Lab 0). Verifique com `echo $OPENSEARCH_ENDPOINT`. Se vazia, execute:
  ```bash
  cd ~/Curso-opensearch/modulo6-lab/lab0-setup/ && ./configurar-ambiente.sh
  ```
- `curl` e `jq` instalados
- Dataset disponível em `../dataset/dataset.json`

## Passo a Passo

### 1️⃣ Setup — Verificar pré-requisitos

```bash
./setup.sh
```

Verifica conectividade com o cluster e variáveis de ambiente.

### 2️⃣ Criar índices com diferentes configurações de shards

Para entender como o número de shards é configurado, veja o curl equivalente:

```bash
# Criar índice com 1 shard (ideal para dataset pequeno)
curl -s -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X PUT "${OPENSEARCH_ENDPOINT}/lab4-shard1" \
  -H "Content-Type: application/json" \
  -d '{"settings": {"number_of_shards": 1, "number_of_replicas": 0}}'

# Criar índice com 5 shards
curl -s -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X PUT "${OPENSEARCH_ENDPOINT}/lab4-shard5" \
  -H "Content-Type: application/json" \
  -d '{"settings": {"number_of_shards": 5, "number_of_replicas": 0}}'

# Criar índice com 20 shards (oversharding para 100 docs)
curl -s -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X PUT "${OPENSEARCH_ENDPOINT}/lab4-shard20" \
  -H "Content-Type: application/json" \
  -d '{"settings": {"number_of_shards": 20, "number_of_replicas": 0}}'
```

O script cria os 3 índices e indexa o mesmo dataset em cada um:

```bash
./criar-indices-shards.sh
```

### 3️⃣ Comparar performance entre os índices

Para entender a comparação, veja o curl que executa a mesma query em cada índice:

```bash
# Mesma query match_all em cada índice — compare o "took"
curl -s -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X GET "${OPENSEARCH_ENDPOINT}/lab4-shard1/_search" \
  -H "Content-Type: application/json" \
  -d '{"query": {"match_all": {}}}' | jq '{index: "lab4-shard1", took, hits: .hits.total.value}'

curl -s -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X GET "${OPENSEARCH_ENDPOINT}/lab4-shard20/_search" \
  -H "Content-Type: application/json" \
  -d '{"query": {"match_all": {}}}' | jq '{index: "lab4-shard20", took, hits: .hits.total.value}'
```

Para a comparação formatada em tabela, execute o script:

```bash
./comparar-performance.sh
```

### 4️⃣ Visualizar distribuição de shards

Veja como os shards estão distribuídos no cluster:

```bash
# Listar shards dos índices lab4-shard*
curl -s -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  "${OPENSEARCH_ENDPOINT}/_cat/shards/lab4-shard*?v&h=index,shard,prirep,state,docs,store,node"
```

Para uma visualização formatada com resumo por índice:

```bash
./ver-shards.sh
```

### 5️⃣ Cleanup — Remover recursos

```bash
./cleanup.sh
```

## Resultado Esperado

Para um dataset pequeno (100 documentos), o índice com **1 shard** deve apresentar performance igual ou superior aos índices com 5 e 20 shards:

| Índice       | Shards | Comportamento esperado                          |
|--------------|--------|-------------------------------------------------|
| lab4-shard1  | 1      | Mais eficiente — sem overhead de coordenação    |
| lab4-shard5  | 5      | Overhead moderado para dataset pequeno          |
| lab4-shard20 | 20     | Maior overhead — 20 shards para 100 documentos  |

> **Nota**: Em clusters de produção com grandes volumes de dados, mais shards podem melhorar a performance. O problema ocorre quando o número de shards é desproporcional ao volume de dados.

## Arquivos

| Arquivo                  | Descrição                                          |
|--------------------------|----------------------------------------------------|
| `setup.sh`               | Verifica pré-requisitos (env vars + conectividade) |
| `criar-indices-shards.sh`| Cria os 3 índices e indexa o dataset em cada um    |
| `comparar-performance.sh`| Executa match_all e compara took entre índices     |
| `ver-shards.sh`          | Exibe distribuição de shards via `_cat/shards`     |
| `cleanup.sh`             | Remove os 3 índices lab4-shard*                    |
