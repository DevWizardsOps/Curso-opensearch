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

```bash
./query-simples-profile.sh
```

Executa uma query `term` simples com `"profile": true` e exibe o `time_in_nanos`.

### 3️⃣ Query Complexa com Profile

```bash
./query-complexa-profile.sh
```

Executa uma query `bool` com `must`, `should` e `filter` com `"profile": true`.
Exibe o tempo de cada fase e compara com a query simples.

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
- Variáveis de ambiente configuradas:

```bash
export OPENSEARCH_ENDPOINT="https://seu-dominio.us-east-1.es.amazonaws.com"
export OPENSEARCH_USER="admin"
export OPENSEARCH_PASS="sua-senha"
```

---

## 💡 Dicas de Interpretação

- **`TermQuery`**: query mais simples, busca exata em campo keyword — `time_in_nanos` baixo
- **`BooleanQuery`**: combina múltiplas queries — `time_in_nanos` é a soma das fases
- **`breakdown.create_weight`**: tempo para preparar a query antes de executar
- **`breakdown.build_scorer`**: tempo para construir o mecanismo de pontuação
- **`breakdown.next_doc`**: tempo iterando sobre documentos correspondentes
- Se a query retornar **zero resultados**, o profile ainda é exibido — isso é esperado e útil para diagnóstico
