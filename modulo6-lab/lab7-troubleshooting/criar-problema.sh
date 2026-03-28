#!/bin/bash
set -e

# =============================================================================
# Lab 7 — Troubleshooting Controlado: Criar Problema
# Cria índice lab7-problema com mapping INCORRETO (timestamp como keyword)
# Indexa documentos com timestamps ISO 8601
# Demonstra que range query retorna 0 resultados (o sintoma do problema)
# =============================================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INDEX_PROBLEMA="lab7-problema"
INDEX_CORRIGIDO="lab7-corrigido"

log()     { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warning() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
error()   { echo -e "${RED}[ERRO]${NC} $1" >&2; }

# Verifica variáveis de ambiente obrigatórias
check_env() {
  local missing=0
  for var in OPENSEARCH_ENDPOINT OPENSEARCH_USER OPENSEARCH_PASS; do
    if [ -z "${!var}" ]; then
      error "Variável ${var} não está definida."
      missing=1
    fi
  done
  if [ "$missing" -eq 1 ]; then
    echo ""
    echo "Configure as variáveis antes de executar:"
    echo "  export OPENSEARCH_ENDPOINT=\"https://seu-dominio.us-east-1.es.amazonaws.com\""
    echo "  export OPENSEARCH_USER=\"admin\""
    echo "  export OPENSEARCH_PASS=\"sua-senha\""
    exit 1
  fi
}

# Verifica conectividade com o cluster
check_connectivity() {
  log "Verificando conectividade com o OpenSearch..."
  local response
  response=$(curl --fail --silent --show-error \
    -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
    "${OPENSEARCH_ENDPOINT}/_cluster/health" 2>&1) || {
    error "OpenSearch não acessível em ${OPENSEARCH_ENDPOINT}"
    error "Detalhes: ${response}"
    exit 1
  }
  local status
  status=$(echo "$response" | jq -r '.status' 2>/dev/null || echo "unknown")
  success "Cluster acessível — status: ${status}"
}

# Deleta um índice se existir
delete_if_exists() {
  local index_name="$1"
  local http_code
  http_code=$(curl --silent -o /dev/null -w "%{http_code}" \
    -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
    "${OPENSEARCH_ENDPOINT}/${index_name}" 2>/dev/null) || true

  if [ "$http_code" = "200" ]; then
    log "Limpando estado anterior: deletando '${index_name}'..."
    curl --fail --silent --show-error -o /dev/null \
      -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
      -X DELETE "${OPENSEARCH_ENDPOINT}/${index_name}" 2>/dev/null || true
    success "Índice '${index_name}' removido."
  fi
}

# =============================================================================
# Execução principal
# =============================================================================

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Lab 7 — Troubleshooting Controlado     ${NC}"
echo -e "${BLUE}  Criar Cenário de Problema               ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

check_env
check_connectivity

# Limpa estado anterior
log "Limpando estado anterior (se existir)..."
delete_if_exists "$INDEX_PROBLEMA"
delete_if_exists "$INDEX_CORRIGIDO"
echo ""

# Cria índice com mapping INCORRETO: timestamp como keyword
log "Criando índice '${INDEX_PROBLEMA}' com mapping INCORRETO..."
warning "timestamp será mapeado como 'keyword' em vez de 'date' — este é o bug!"
echo ""

response=$(curl --fail --silent --show-error \
  -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X PUT "${OPENSEARCH_ENDPOINT}/${INDEX_PROBLEMA}" \
  -H "Content-Type: application/json" \
  -d '{
    "settings": {
      "number_of_shards": 1,
      "number_of_replicas": 0
    },
    "mappings": {
      "properties": {
        "id":        { "type": "keyword" },
        "nome":      { "type": "text" },
        "status":    { "type": "keyword" },
        "descricao": { "type": "text" },
        "usuario":   { "type": "keyword" },
        "timestamp": { "type": "keyword" }
      }
    }
  }' 2>&1) || {
  error "Falha ao criar índice '${INDEX_PROBLEMA}'"
  error "Detalhes: ${response}"
  exit 1
}

success "Índice '${INDEX_PROBLEMA}' criado com mapping INCORRETO (timestamp=keyword)."
echo ""

# Indexa 10 documentos com timestamps ISO 8601
log "Indexando 10 documentos com timestamps ISO 8601..."

bulk_data='{"index":{"_index":"lab7-problema"}}
{"id":"doc-001","nome":"Produto Alpha","status":"ativo","descricao":"Produto de teste para troubleshooting","usuario":"user_001","timestamp":"2024-01-15T10:30:00Z"}
{"index":{"_index":"lab7-problema"}}
{"id":"doc-002","nome":"Produto Beta","status":"inativo","descricao":"Produto de teste para troubleshooting","usuario":"user_002","timestamp":"2024-02-20T14:45:00Z"}
{"index":{"_index":"lab7-problema"}}
{"id":"doc-003","nome":"Produto Gamma","status":"ativo","descricao":"Produto de teste para troubleshooting","usuario":"user_003","timestamp":"2024-03-10T09:00:00Z"}
{"index":{"_index":"lab7-problema"}}
{"id":"doc-004","nome":"Produto Delta","status":"pendente","descricao":"Produto de teste para troubleshooting","usuario":"user_004","timestamp":"2024-04-05T16:20:00Z"}
{"index":{"_index":"lab7-problema"}}
{"id":"doc-005","nome":"Produto Epsilon","status":"ativo","descricao":"Produto de teste para troubleshooting","usuario":"user_005","timestamp":"2024-05-12T11:15:00Z"}
{"index":{"_index":"lab7-problema"}}
{"id":"doc-006","nome":"Produto Zeta","status":"inativo","descricao":"Produto de teste para troubleshooting","usuario":"user_006","timestamp":"2024-06-18T08:30:00Z"}
{"index":{"_index":"lab7-problema"}}
{"id":"doc-007","nome":"Produto Eta","status":"ativo","descricao":"Produto de teste para troubleshooting","usuario":"user_007","timestamp":"2024-07-22T13:00:00Z"}
{"index":{"_index":"lab7-problema"}}
{"id":"doc-008","nome":"Produto Theta","status":"pendente","descricao":"Produto de teste para troubleshooting","usuario":"user_008","timestamp":"2024-08-30T17:45:00Z"}
{"index":{"_index":"lab7-problema"}}
{"id":"doc-009","nome":"Produto Iota","status":"ativo","descricao":"Produto de teste para troubleshooting","usuario":"user_009","timestamp":"2024-09-14T10:00:00Z"}
{"index":{"_index":"lab7-problema"}}
{"id":"doc-010","nome":"Produto Kappa","status":"inativo","descricao":"Produto de teste para troubleshooting","usuario":"user_010","timestamp":"2024-10-25T15:30:00Z"}'

response=$(echo "$bulk_data" | curl --fail --silent --show-error \
  -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X POST "${OPENSEARCH_ENDPOINT}/_bulk" \
  -H "Content-Type: application/json" \
  --data-binary @- 2>&1) || {
  error "Falha na ingestão dos documentos"
  error "Detalhes: ${response}"
  exit 1
}

errors=$(echo "$response" | jq '.errors' 2>/dev/null || echo "false")
if [ "$errors" = "true" ]; then
  warning "Alguns documentos tiveram erros durante a indexação."
else
  success "10 documentos indexados com sucesso em '${INDEX_PROBLEMA}'."
fi
echo ""

# Aguarda indexação
sleep 1

# Demonstra o problema: date_histogram aggregation falha com keyword
echo -e "${RED}========================================${NC}"
echo -e "${RED}  Demonstração do Sintoma                ${NC}"
echo -e "${RED}========================================${NC}"
echo ""
log "Executando date_histogram aggregation em 'timestamp'..."
log "Essa aggregation só funciona com campos do tipo 'date'."
echo ""

agg_response=$(curl --silent --show-error \
  -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X GET "${OPENSEARCH_ENDPOINT}/${INDEX_PROBLEMA}/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "size": 0,
    "aggs": {
      "docs_por_mes": {
        "date_histogram": {
          "field": "timestamp",
          "calendar_interval": "month"
        }
      }
    }
  }' 2>&1)

agg_status=$(echo "$agg_response" | jq -r '.status // empty' 2>/dev/null || echo "")
agg_error=$(echo "$agg_response" | jq -r '.error.type // empty' 2>/dev/null || echo "")

echo ""
if [ -n "$agg_error" ] || [ "$agg_status" = "400" ] || [ "$agg_status" = "500" ]; then
  echo -e "${RED}========================================${NC}"
  echo -e "${RED}  ❌ SINTOMA CONFIRMADO                  ${NC}"
  echo -e "${RED}========================================${NC}"
  echo ""
  error "date_histogram falhou no campo 'timestamp'!"
  echo ""
  echo -e "  ${YELLOW}Erro retornado:${NC}"
  echo "$agg_response" | jq -r '.error.reason // .error.root_cause[0].reason // "Erro desconhecido"' 2>/dev/null | head -3
  echo ""
  warning "O OpenSearch não consegue executar date_histogram em campos 'keyword'."
  warning "Causa raiz: campo 'timestamp' mapeado como 'keyword' em vez de 'date'."
else
  # Tenta também range com "now" que falha com keyword
  log "Executando range query com 'now-2y' (expressão de data)..."
  echo ""
  now_response=$(curl --silent --show-error \
    -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
    -X GET "${OPENSEARCH_ENDPOINT}/${INDEX_PROBLEMA}/_search" \
    -H "Content-Type: application/json" \
    -d '{
      "query": {
        "range": {
          "timestamp": { "gte": "now-2y", "lte": "now" }
        }
      }
    }' 2>&1)

  now_hits=$(echo "$now_response" | jq '.hits.total.value' 2>/dev/null || echo "0")
  now_error=$(echo "$now_response" | jq -r '.error.type // empty' 2>/dev/null || echo "")

  if [ -n "$now_error" ] || [ "$now_hits" = "0" ] || [ "$now_hits" = "null" ]; then
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}  ❌ SINTOMA CONFIRMADO                  ${NC}"
    echo -e "${RED}========================================${NC}"
    echo ""
    error "Range query com 'now-2y' retornou ${now_hits:-0} resultados (deveria retornar 10)!"
    warning "Expressões como 'now-2y' não funcionam em campos 'keyword'."
    warning "Causa raiz: campo 'timestamp' mapeado como 'keyword' em vez de 'date'."
  else
    warning "Range query retornou ${now_hits} resultados."
    warning "Execute ./diagnosticar.sh para investigar o mapping."
  fi
fi

echo ""
echo -e "${YELLOW}  Próximo passo: execute ${GREEN}./diagnosticar.sh${YELLOW} para investigar o problema.${NC}"
echo ""
