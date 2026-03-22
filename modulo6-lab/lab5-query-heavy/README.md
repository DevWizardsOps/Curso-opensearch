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

- Variáveis de ambiente configuradas:
  ```bash
  export OPENSEARCH_ENDPOINT="https://seu-dominio.us-east-1.es.amazonaws.com"
  export OPENSEARCH_USER="admin"
  export OPENSEARCH_PASS="sua-senha"
  ```
- `curl` e `jq` instalados
- Dataset disponível em `../dataset/dataset-large.json` (1000 docs)

## Passo a Passo

```bash
# 1. Criar índice e indexar dataset-large.json (1000 docs)
./setup.sh

# 2. Executar wildcard query + aggregation (query custosa)
./query-wildcard-agg.sh

# 3. Executar term query + aggregation (query otimizada)
./query-otimizada.sh

# 4. Limpar recursos criados
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
