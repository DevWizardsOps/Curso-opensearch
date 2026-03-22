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

1. Range query em `timestamp` retorna 0 resultados (ou resultados incorretos)
2. Não há mensagem de erro — o OpenSearch executa a query sem reclamar
3. O mapping mostra `"type": "keyword"` para o campo `timestamp`

## Processo de Diagnóstico

```
1. Verificar o mapping do índice
   GET /lab7-problema/_mapping
   → Identifica que timestamp é keyword, não date

2. Executar range query que falha
   GET /lab7-problema/_search com range em timestamp
   → Confirma que retorna 0 resultados

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

- Variáveis de ambiente configuradas:
  ```bash
  export OPENSEARCH_ENDPOINT="https://seu-dominio.us-east-1.es.amazonaws.com"
  export OPENSEARCH_USER="admin"
  export OPENSEARCH_PASS="sua-senha"
  ```
- `curl` e `jq` instalados

## Passo a Passo

```bash
# 1. Criar o cenário de problema (índice com mapping incorreto)
./criar-problema.sh

# 2. Diagnosticar o problema passo a passo
./diagnosticar.sh

# 3. Corrigir o problema (reindex para índice com mapping correto)
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
