#!/bin/bash
set -e

# =============================================================================
# Lab 1 — Bulk Indexing: Setup
# Cria o índice lab1-produtos com mapping padrão
# =============================================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

INDEX_NAME="lab1-produtos"

# Funções de log
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

# Verifica se o índice já existe
index_exists() {
  curl --fail --silent --show-error -o /dev/null \
    -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
    "${OPENSEARCH_ENDPOINT}/${INDEX_NAME}" 2>/dev/null
  return $?
}

# Cria o índice com mapping padrão
create_index() {
  log "Criando índice '${INDEX_NAME}'..."
  local response
  response=$(curl --fail --silent --show-error \
    -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
    -X PUT "${OPENSEARCH_ENDPOINT}/${INDEX_NAME}" \
    -H "Content-Type: application/json" \
    -d '{
      "settings": {
        "number_of_shards": 1,
        "number_of_replicas": 0
      },
      "mappings": {
        "properties": {
          "id":        { "type": "keyword" },
          "nome":      { "type": "text", "fields": { "keyword": { "type": "keyword" } } },
          "status":    { "type": "keyword" },
          "descricao": { "type": "text" },
          "usuario":   { "type": "keyword" },
          "timestamp": { "type": "date", "format": "strict_date_time" }
        }
      }
    }' 2>&1) || {
    error "Falha ao criar índice '${INDEX_NAME}'"
    error "Detalhes: ${response}"
    exit 1
  }
  success "Índice '${INDEX_NAME}' criado com sucesso."
}

# =============================================================================
# Execução principal
# =============================================================================

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Lab 1 — Bulk Indexing: Setup          ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

check_env
check_connectivity

if index_exists; then
  warning "Índice '${INDEX_NAME}' já existe. Nenhuma ação necessária."
else
  create_index
fi

echo ""
success "Setup concluído. Índice '${INDEX_NAME}' está pronto."
echo ""
