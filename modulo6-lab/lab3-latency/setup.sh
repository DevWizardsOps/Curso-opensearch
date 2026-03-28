#!/bin/bash
set -e

# =============================================================================
# Lab 3 — Diagnóstico de Latência com Profile API: Setup
# Cria o índice lab3-produtos e indexa o dataset padrão
# =============================================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

INDEX_NAME="lab3-produtos"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATASET_PATH="${SCRIPT_DIR}/../dataset/dataset.json"

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

# Indexa o dataset via POST /_bulk substituindo o nome do índice
index_dataset() {
  if [ ! -f "$DATASET_PATH" ]; then
    error "Dataset não encontrado em ${DATASET_PATH}"
    error "Certifique-se de que o dataset foi criado em modulo6-lab/dataset/dataset.json"
    exit 1
  fi

  local total
  total=$(awk 'NR%2==0' "$DATASET_PATH" | wc -l | tr -d ' ')
  log "Indexando ${total} documentos via bulk API..."

  # Substitui "_index": "<qualquer>" por "_index": "lab3-produtos" antes de enviar
  local bulk_data
  bulk_data=$(sed 's/"_index"[[:space:]]*:[[:space:]]*"[^"]*"/"_index": "'"${INDEX_NAME}"'"/g' "$DATASET_PATH")

  local response
  response=$(echo "$bulk_data" | curl --fail --silent --show-error \
    -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
    -X POST "${OPENSEARCH_ENDPOINT}/_bulk" \
    -H "Content-Type: application/json" \
    --data-binary @- 2>&1) || {
    error "Falha na ingestão bulk do dataset"
    error "Detalhes: ${response}"
    exit 1
  }

  local errors
  errors=$(echo "$response" | jq '.errors' 2>/dev/null || echo "false")
  if [ "$errors" = "true" ]; then
    local failed
    failed=$(echo "$response" | jq '[.items[] | select(.index.error != null)] | length' 2>/dev/null || echo "?")
    warning "Alguns documentos tiveram erros: ${failed} falhas"
  else
    success "${total} documentos indexados com sucesso."
  fi
}

# =============================================================================
# Execução principal
# =============================================================================

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Lab 3 — Diagnóstico de Latência        ${NC}"
echo -e "${BLUE}  Setup                                  ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

check_env
check_connectivity

if index_exists; then
  warning "Índice '${INDEX_NAME}' já existe. Verificando contagem de documentos..."
  doc_count=$(curl --fail --silent --show-error \
    -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
    "${OPENSEARCH_ENDPOINT}/${INDEX_NAME}/_count" 2>/dev/null | jq '.count' 2>/dev/null || echo "0")
  log "Documentos no índice: ${doc_count}"
  if [ "${doc_count}" -gt 0 ] 2>/dev/null; then
    success "Índice '${INDEX_NAME}' já está pronto com ${doc_count} documentos."
  else
    warning "Índice existe mas está vazio. Indexando dataset..."
    index_dataset
  fi
else
  create_index
  index_dataset
fi

echo ""
success "Setup concluído. Índice '${INDEX_NAME}' está pronto para o lab."
echo ""
