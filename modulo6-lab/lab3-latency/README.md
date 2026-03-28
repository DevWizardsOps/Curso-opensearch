# 🔬 Lab 3 — Diagnóstico de Latência com Profile API

## 🎯 Objetivo

Usar o endpoint `_profile` do OpenSearch para diagnosticar a latência de queries, identificando quais fases consomem mais tempo durante a execução de uma busca.

---

## 📖 O que é a Profile API?

A **Profile API** é um recurso do OpenSearch que permite inspecionar a execução interna de uma query. Ao adicionar `"profile": true` em qualquer requisição `_search`, o OpenSearch retorna um relatório detalhado com o tempo gasto em cada fase da busca.

### Como usar

Basta adicionar `"profile": true` no corpo da requisição:

```json
GET /meu-indice/_search
{
  "profile": true,
  "query": {
    "term": { "status": "ativo" }
  }
}
```

### Como interpretar `time_in_nanos`

O campo `time_in_nanos` representa o tempo de execução em **nanossegundos** (1 ms = 1.000.000 ns). Quanto maior o valor, mais tempo aquela fase da query consumiu.

---

## 🗂️ Estrutura do Output do Profile

O response JSON do `_profile` segue esta hierarquia:

```
profile
└── shards[]                    ← um por shard do índice
    └── searches[]              ← uma por fase de busca
        └── query[]             ← árvore de queries executadas
            ├── type            ← tipo da query (TermQuery, BooleanQuery, etc.)
            ├── description     ← detalhes da query
            ├── time_in_nanos   ← tempo total desta query em nanossegundos
            ├── breakdown       ← tempo detalhado por operação interna
            └── children[]      ← sub-queries (para bool, must, should, filter)
                ├── type
                ├── time_in_nanos
                └── breakdown
```

### Exemplo de output formatado

```json
{
  "profile": {
    "shards": [
      {
        "searches": [
          {
            "query": [
              {
                "type": "TermQuery",
                "description": "status:ativo",
                "time_in_nanos": 45230,
                "breakdown": {
                  "score": 0,
                  "create_weight": 12100,
                  "next_doc": 8900,
                  "advance": 0,
                  "match": 0,
                  "build_scorer": 24230
                }
              }
            ]
          }
        ]
      }
    ]
  }
}
```

---

## 🚀 Passo a Passo

Execute os scripts na seguinte ordem:

### 1️⃣ Setup — Criar índice e indexar dataset

```bash
./setup.sh
```

Cria o índice `lab3-produtos` e indexa o dataset padrão (100 documentos).

### 2️⃣ Query Simples com Profile

A Profile API é ativada adicionando `"profile": true` na requisição. Veja o curl equivalente para uma query `term` simples:

```bash
# Query simples (TermQuery) com profile habilitado
curl -s -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X GET "${OPENSEARCH_ENDPOINT}/lab3-produtos/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "profile": true,
    "query": {
      "term": { "status": "ativo" }
    }
  }' | jq '.profile.shards[0].searches[0].query[] | {type, description, time_in_nanos, breakdown: {create_weight: .breakdown.create_weight, build_scorer: .breakdown.build_scorer, next_doc: .breakdown.next_doc}}'
```

O output mostra o tipo da query (`TermQuery`), o `time_in_nanos` total e o breakdown por fase interna.

Para uma visualização formatada com comparação, execute o script:

```bash
./query-simples-profile.sh
```

### 3️⃣ Query Complexa com Profile

Agora uma query `bool` com múltiplas cláusulas — observe como o profile detalha cada sub-query:

```bash
# Query complexa (BooleanQuery) com must + should + filter
curl -s -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X GET "${OPENSEARCH_ENDPOINT}/lab3-produtos/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "profile": true,
    "query": {
      "bool": {
        "must": [
          { "match": { "descricao": "produto" } }
        ],
        "should": [
          { "term": { "status": "ativo" } }
        ],
        "filter": [
          { "range": { "timestamp": { "gte": "2024-01-01T00:00:00Z" } } }
        ]
      }
    }
  }' | jq '.profile.shards[0].searches[0].query[] | {type, time_in_nanos, children: [.children[]? | {type, time_in_nanos}]}'
```

Note que o `BooleanQuery` tem `children` — cada sub-query (`must`, `should`, `filter`) aparece com seu próprio `time_in_nanos`. A soma das fases explica a latência total.

Para uma visualização formatada com comparação entre query simples e complexa, execute o script:

```bash
./query-complexa-profile.sh
```

### 4️⃣ Cleanup — Remover recursos

```bash
./cleanup.sh
```

Remove o índice `lab3-produtos`.

---

## ✅ Resultado Esperado

| Query | Tipo | `time_in_nanos` esperado |
|---|---|---|
| Query simples | `TermQuery` | Menor (operação direta) |
| Query complexa | `BooleanQuery` | Maior (múltiplas fases) |

> 💡 A query complexa deve apresentar `time_in_nanos` **maior** que a query simples, pois envolve múltiplas sub-queries (`must`, `should`, `filter`) que são executadas e somadas internamente.

---

## 📋 Pré-requisitos

- `curl` instalado
- `jq` instalado
- Variáveis de ambiente configuradas (feito no Lab 0). Verifique com `echo $OPENSEARCH_ENDPOINT`. Se vazia, execute:

```bash
cd ~/Curso-opensearch/modulo6-lab/lab0-setup/ && ./configurar-ambiente.sh
```

---

## 💡 Dicas de Interpretação

- **`TermQuery`**: query mais simples, busca exata em campo keyword — `time_in_nanos` baixo
- **`BooleanQuery`**: combina múltiplas queries — `time_in_nanos` é a soma das fases
- **`breakdown.create_weight`**: tempo para preparar a query antes de executar
- **`breakdown.build_scorer`**: tempo para construir o mecanismo de pontuação
- **`breakdown.next_doc`**: tempo iterando sobre documentos correspondentes
- Se a query retornar **zero resultados**, o profile ainda é exibido — isso é esperado e útil para diagnóstico
