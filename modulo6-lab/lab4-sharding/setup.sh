#!/bin/bash
set -e

# =============================================================================
# Lab 4 — Oversharding: Setup
# Verifica pré-requisitos de cluster (env vars + conectividade)
# A criação dos índices é feita pelo script criar-indices-shards.sh
# =============================================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATASET_PATH="${SCRIPT_DIR}/../dataset/dataset.json"

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

# Verifica se o dataset existe
check_dataset() {
  if [ ! -f "$DATASET_PATH" ]; then
    error "Dataset não encontrado em ${DATASET_PATH}"
    error "Certifique-se de que o arquivo modulo6-lab/dataset/dataset.json existe."
    exit 1
  fi
  local total
  total=$(awk 'NR%2==0' "$DATASET_PATH" | wc -l | tr -d ' ')
  success "Dataset encontrado: ${total} documentos em ${DATASET_PATH}"
}

# =============================================================================
# Execução principal
# =============================================================================

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Lab 4 — Oversharding: Setup            ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

check_env
check_connectivity
check_dataset

echo ""
success "Pré-requisitos verificados com sucesso."
echo ""
log "Próximo passo: execute ./criar-indices-shards.sh para criar os índices."
echo ""
