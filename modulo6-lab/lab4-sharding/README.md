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

```bash
# 1. Verificar pré-requisitos
./setup.sh

# 2. Criar os 3 índices com configurações distintas de shards e indexar o dataset
./criar-indices-shards.sh

# 3. Comparar performance de query entre os índices
./comparar-performance.sh

# 4. Visualizar distribuição de shards no cluster
./ver-shards.sh

# 5. Limpar recursos criados
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
