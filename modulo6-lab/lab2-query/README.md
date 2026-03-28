# 🔍 Lab 2 — Filter vs Query Context

## 🎯 Objetivo

Entender a diferença entre **query context** e **filter context** no OpenSearch, e como essa escolha impacta a performance das consultas.

---

## 📚 Conceitos

### Query Context — Calcula Relevância (_score)

No **query context**, o OpenSearch responde à pergunta:
> *"Quão bem este documento corresponde à consulta?"*

- Calcula o `_score` de relevância para cada documento
- Usa algoritmos como BM25 para ranquear resultados
- **Mais custoso computacionalmente** — não usa cache de filtros
- Ideal para **busca full-text** onde a ordem de relevância importa

```json
{
  "query": {
    "match": {
      "descricao": "produto"
    }
  }
}
```

### Filter Context — Sem Score, Com Cache

No **filter context**, o OpenSearch responde à pergunta:
> *"Este documento corresponde à condição? Sim ou não."*

- **Não calcula** `_score` (todos os documentos retornam `_score: 0` ou `null`)
- Resultados são **cacheados automaticamente** pelo OpenSearch
- **Mais eficiente** para filtros exatos e condições booleanas
- Ideal para filtros por **status, datas, IDs, ranges numéricos**

```json
{
  "query": {
    "bool": {
      "filter": [
        { "term": { "status": "ativo" } }
      ]
    }
  }
}
```

### Quando Usar Cada Um

| Situação | Contexto Recomendado |
|---|---|
| Busca full-text em campos de texto | Query Context (`match`, `multi_match`) |
| Filtro por valor exato (status, ID) | Filter Context (`term`, `terms`) |
| Filtro por intervalo de datas/números | Filter Context (`range`) |
| Busca com relevância + filtros | Ambos: `must` (query) + `filter` |
| Performance crítica com filtros repetidos | Filter Context (aproveita cache) |

---

## 🛠️ Pré-requisitos

- Variáveis de ambiente configuradas (feito no Lab 0). Verifique com `echo $OPENSEARCH_ENDPOINT`. Se vazia, execute:
  ```bash
  cd ~/Curso-opensearch/modulo6-lab/lab0-setup/ && ./configurar-ambiente.sh
  ```
- `curl` e `jq` instalados

---

## 📋 Passo a Passo

### 1️⃣ Setup — Criar índice e indexar dataset

```bash
./setup.sh
```

Cria o índice `lab2-produtos` e indexa o dataset padrão (100 documentos).

### 2️⃣ Query Context — Busca com cálculo de score

No query context, o OpenSearch calcula o `_score` de relevância para cada documento. Veja o curl equivalente:

```bash
# Busca full-text com match — calcula _score de relevância
curl -s -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X GET "${OPENSEARCH_ENDPOINT}/lab2-produtos/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "match": {
        "descricao": "produto"
      }
    }
  }' | jq '{took, hits: .hits.total.value, max_score: .hits.max_score}'
```

Note que o response inclui `_score` e `max_score` — o OpenSearch ranqueou os documentos por relevância.

Para medir o tempo e comparar com o filter context, execute o script:

```bash
./query-context.sh
```

### 3️⃣ Filter Context — Filtro sem cálculo de score

No filter context, o OpenSearch responde apenas "sim ou não" — sem calcular relevância. Veja o curl equivalente:

```bash
# Filtro exato com bool.filter + term — sem _score, com cache
curl -s -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X GET "${OPENSEARCH_ENDPOINT}/lab2-produtos/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "bool": {
        "filter": [
          { "term": { "status": "ativo" } }
        ]
      }
    }
  }' | jq '{took, hits: .hits.total.value, max_score: .hits.max_score}'
```

Note que `max_score` retorna `0.0` ou `null` — nenhum cálculo de relevância foi feito. Execute novamente e observe que o `took` diminui (cache de filtros).

Para medir e comparar automaticamente, execute o script:

```bash
./filter-context.sh
```

### 4️⃣ Cleanup — Remover recursos

```bash
./cleanup.sh
```

Remove o índice `lab2-produtos` e arquivos temporários.

---

## 📊 Resultado Esperado

Após executar os dois scripts de consulta, você verá uma comparação de tempo (`took` em ms):

```
========================================
  Comparação: Query vs Filter Context
========================================

  Método          took (ms)   Hits
  --------------- ----------- --------
  Query Context   12          100
  Filter Context  3           67

💡 Filter context foi mais rápido!
   Motivo: sem cálculo de _score + uso de cache de filtros
========================================
```

> **Por que filter context é mais eficiente?**
> 1. **Sem cálculo de score**: não executa BM25 nem outros algoritmos de relevância
> 2. **Cache de filtros**: o OpenSearch armazena o resultado em bitset cache, reutilizando em consultas subsequentes
> 3. **Menos CPU**: operação binária (sim/não) vs operação de pontuação (float)

---

## 🔗 Referências

- [OpenSearch — Query and Filter Context](https://opensearch.org/docs/latest/query-dsl/query-filter-context/)
- [OpenSearch — Bool Query](https://opensearch.org/docs/latest/query-dsl/compound/bool/)
- [OpenSearch — Term Query](https://opensearch.org/docs/latest/query-dsl/term/term/)
