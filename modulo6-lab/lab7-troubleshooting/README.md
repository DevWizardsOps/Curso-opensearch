# Lab 7 — Troubleshooting Controlado

## Objetivo

Identificar e corrigir um problema controlado no OpenSearch, desenvolvendo habilidades de diagnóstico em cenários reais.

## Cenário do Problema

### Descrição

Um índice foi criado com um **mapping incorreto**: o campo `timestamp` foi mapeado como `keyword` em vez de `date`. Isso causa um comportamento silencioso e difícil de detectar:

- Os documentos são indexados normalmente (sem erro)
- Queries de texto funcionam normalmente
- **Range queries em `timestamp` retornam 0 resultados** — o problema não é óbvio

### Por que isso acontece?

Quando `timestamp` é mapeado como `keyword`:
- O OpenSearch armazena o valor como string literal (ex: `"2024-01-15T10:30:00Z"`)
- Uma range query como `{"range": {"timestamp": {"gte": "2024-01-01"}}}` compara **strings lexicograficamente**, não datas
- A comparação lexicográfica de strings ISO 8601 pode funcionar em alguns casos, mas falha quando os formatos não são idênticos ou quando o OpenSearch tenta interpretar como data

### Sintomas

1. `date_histogram` aggregation em `timestamp` retorna erro
2. Range queries com expressões como `now-1y` falham ou retornam 0 resultados
3. Range queries com strings ISO 8601 fixas podem funcionar "por acidente" (comparação lexicográfica)
4. Não há mensagem de erro na indexação — o OpenSearch aceita os documentos normalmente
5. O mapping mostra `"type": "keyword"` para o campo `timestamp`

## Processo de Diagnóstico

```
1. Verificar o mapping do índice
   GET /lab7-problema/_mapping
   → Identifica que timestamp é keyword, não date

2. Executar date_histogram aggregation
   GET /lab7-problema/_search com date_histogram em timestamp
   → Falha com erro — date_histogram não funciona em campos keyword

3. Verificar saúde geral do cluster
   GET /_cluster/health
   → Confirma que o problema é de mapping, não de infraestrutura
```

## Processo de Correção

```
1. Criar novo índice com mapping CORRETO (timestamp como date)
   PUT /lab7-corrigido

2. Reindexar dados do índice problemático para o corrigido
   POST /_reindex

3. Validar que range query funciona no novo índice
   GET /lab7-corrigido/_search com range em timestamp
   → Deve retornar resultados

4. Verificar saúde do cluster após a correção
   GET /_cluster/health
   → Deve ser green ou yellow
```

## Pré-requisitos

- Variáveis de ambiente configuradas (feito no Lab 0). Verifique com `echo $OPENSEARCH_ENDPOINT`. Se vazia, execute:
  ```bash
  cd ~/Curso-opensearch/modulo6-lab/lab0-setup/ && ./configurar-ambiente.sh
  ```
- `curl` e `jq` instalados

## Passo a Passo

### 1️⃣ Criar o cenário de problema

O script cria um índice com mapping incorreto (`timestamp` como `keyword`) e indexa documentos. Veja o curl equivalente do mapping incorreto:

```bash
# Mapping INCORRETO — timestamp como keyword (deveria ser date)
curl -s -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X PUT "${OPENSEARCH_ENDPOINT}/lab7-problema" \
  -H "Content-Type: application/json" \
  -d '{
    "mappings": {
      "properties": {
        "timestamp": { "type": "keyword" }
      }
    }
  }'
```

Para criar o cenário completo (mapping + documentos + demonstração do sintoma):

```bash
./criar-problema.sh
```

### 2️⃣ Diagnosticar o problema

Siga o diagnóstico manualmente para entender cada passo:

```bash
# Passo 1: Verificar o mapping — note que timestamp é "keyword"
curl -s -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  "${OPENSEARCH_ENDPOINT}/lab7-problema/_mapping" | jq '.lab7_problema.mappings.properties.timestamp'

# Passo 2: Executar date_histogram — FALHA com keyword (só funciona com date)
curl -s -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X GET "${OPENSEARCH_ENDPOINT}/lab7-problema/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "size": 0,
    "aggs": {
      "docs_por_mes": {
        "date_histogram": { "field": "timestamp", "calendar_interval": "month" }
      }
    }
  }' | jq '{error: .error.reason}'

# Passo 3: Verificar saúde do cluster — confirma que não é problema de infra
curl -s -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  "${OPENSEARCH_ENDPOINT}/_cluster/health" | jq '{status, unassigned_shards}'
```

Para o diagnóstico guiado com explicações:

```bash
./diagnosticar.sh
```

### 3️⃣ Corrigir o problema

A correção envolve criar um novo índice com mapping correto e reindexar. Veja os curls:

```bash
# Criar índice com mapping CORRETO — timestamp como date
curl -s -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X PUT "${OPENSEARCH_ENDPOINT}/lab7-corrigido" \
  -H "Content-Type: application/json" \
  -d '{
    "mappings": {
      "properties": {
        "timestamp": { "type": "date" }
      }
    }
  }'

# Reindexar dados do índice problemático para o corrigido
curl -s -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X POST "${OPENSEARCH_ENDPOINT}/_reindex" \
  -H "Content-Type: application/json" \
  -d '{
    "source": { "index": "lab7-problema" },
    "dest": { "index": "lab7-corrigido" }
  }'

# Validar — agora a range query retorna resultados
curl -s -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X GET "${OPENSEARCH_ENDPOINT}/lab7-corrigido/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "range": { "timestamp": { "gte": "2024-01-01T00:00:00Z", "lte": "2024-12-31T23:59:59Z" } }
    }
  }' | jq '{took, hits: .hits.total.value}'
```

Para a correção completa com validação e status do cluster:

```bash
./corrigir.sh
```

## Resultado Esperado

| Etapa           | Índice          | Range query em timestamp | Resultado         |
|-----------------|-----------------|--------------------------|-------------------|
| Após criar-problema | lab7-problema | `gte: "2024-01-01"`  | 0 resultados ❌   |
| Após corrigir   | lab7-corrigido  | `gte: "2024-01-01"`      | N resultados ✅   |

## Arquivos

| Arquivo            | Descrição                                                    |
|--------------------|--------------------------------------------------------------|
| `criar-problema.sh`| Cria índice com mapping incorreto e demonstra o sintoma      |
| `diagnosticar.sh`  | Guia o diagnóstico: mapping → range query → cluster health   |
| `corrigir.sh`      | Cria índice correto, reindexia e valida a correção           |

> **Nota**: Este lab não possui `cleanup.sh` separado — `criar-problema.sh` limpa o estado anterior automaticamente ao ser executado novamente.
