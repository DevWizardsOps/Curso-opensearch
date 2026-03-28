# Lab 5 — Query Pesada Controlada

## Objetivo

Observar o impacto de queries custosas (**wildcard + aggregation**) no OpenSearch e comparar com uma abordagem otimizada, entendendo quais padrões de consulta devem ser evitados em produção.

## Conceitos

### Wildcard Query — Alto Custo Computacional

A **wildcard query** (`*produto*`) é uma das queries mais custosas no OpenSearch porque:

- **Não usa o índice invertido de forma eficiente**: precisa varrer todos os termos do campo
- **Sem cache**: wildcards com `*` no início não podem ser cacheados pelo OpenSearch
- **Escala linearmente** com o volume de dados — quanto mais documentos, mais lento
- **Consome CPU**: cada documento precisa ser avaliado individualmente

```json
// ❌ Evitar em produção com grandes volumes
{ "query": { "wildcard": { "descricao": "*produto*" } } }
```

### Aggregation — Custo Adicional

**Aggregations** (como `terms`) calculam estatísticas sobre os resultados da query. Combinadas com wildcard, o custo é multiplicado:

1. Primeiro, o OpenSearch executa a wildcard (cara)
2. Depois, executa a aggregation sobre os resultados (cara)

### Abordagem Otimizada

Use **term query** em campos `keyword` para filtros exatos — é muito mais eficiente:

```json
// ✅ Preferir em produção
{ "query": { "term": { "status": "ativo" } } }
```

**Por que é mais rápido?**
- Usa o índice invertido diretamente (lookup O(1))
- Resultado é cacheado pelo filter cache do OpenSearch
- Não precisa varrer todos os documentos

### Importante

Este lab foca exclusivamente no **impacto da query** — sem geração de carga artificial ou ferramentas externas. O objetivo é observar a diferença de `took` entre as duas abordagens.

## Pré-requisitos

- Variáveis de ambiente configuradas (feito no Lab 0). Verifique com `echo $OPENSEARCH_ENDPOINT`. Se vazia, execute:
  ```bash
  cd ~/Curso-opensearch/modulo6-lab/lab0-setup/ && ./configurar-ambiente.sh
  ```
- `curl` e `jq` instalados
- Dataset disponível em `../dataset/dataset-large.json` (1000 docs)

## Passo a Passo

### 1️⃣ Setup — Criar índice e indexar dataset grande

```bash
./setup.sh
```

Cria o índice `lab5-produtos` e indexa o `dataset-large.json` (1000 documentos).

### 2️⃣ Query custosa — Wildcard + Aggregation

Veja o curl equivalente da query custosa:

```bash
# Wildcard query (varre todos os termos) + terms aggregation
curl -s -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X GET "${OPENSEARCH_ENDPOINT}/lab5-produtos/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "size": 0,
    "query": {
      "wildcard": { "descricao": "*produto*" }
    },
    "aggs": {
      "por_status": {
        "terms": { "field": "status" }
      }
    }
  }' | jq '{took, hits: .hits.total.value, buckets: .aggregations.por_status.buckets}'
```

Note o `"size": 0` — retorna apenas as aggregations, sem documentos. O `took` reflete o custo da wildcard + aggregation.

Para medir e salvar o resultado para comparação:

```bash
./query-wildcard-agg.sh
```

### 3️⃣ Query otimizada — Term + Aggregation

Agora a mesma aggregation, mas com `term` em vez de `wildcard`:

```bash
# Term query (lookup direto no índice invertido) + terms aggregation
curl -s -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X GET "${OPENSEARCH_ENDPOINT}/lab5-produtos/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "size": 0,
    "query": {
      "term": { "status": "ativo" }
    },
    "aggs": {
      "por_status": {
        "terms": { "field": "status" }
      }
    }
  }' | jq '{took, hits: .hits.total.value, buckets: .aggregations.por_status.buckets}'
```

Compare o `took` — o `term` usa lookup O(1) no índice invertido, enquanto o `wildcard` varre todos os termos.

Para a comparação formatada com o resultado da wildcard:

```bash
./query-otimizada.sh
```

### 4️⃣ Cleanup — Remover recursos

```bash
./cleanup.sh
```

## Resultado Esperado

A query otimizada (`term`) deve apresentar `took` menor que a wildcard query, especialmente com 1000 documentos:

| Query                    | Tipo      | Comportamento esperado                    |
|--------------------------|-----------|-------------------------------------------|
| wildcard + aggregation   | Custosa   | `took` maior — varre todos os documentos  |
| term + aggregation       | Otimizada | `took` menor — usa índice invertido        |

> **Nota**: Em datasets pequenos, a diferença pode ser mínima. Com milhões de documentos, a diferença é dramática.

## Arquivos

| Arquivo                  | Descrição                                              |
|--------------------------|--------------------------------------------------------|
| `setup.sh`               | Cria índice lab5-produtos e indexa dataset-large.json  |
| `query-wildcard-agg.sh`  | Executa wildcard + terms aggregation (query custosa)   |
| `query-otimizada.sh`     | Executa term + terms aggregation (query otimizada)     |
| `cleanup.sh`             | Remove índice lab5-produtos e arquivos temporários     |
