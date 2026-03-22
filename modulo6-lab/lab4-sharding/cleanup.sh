#!/bin/bash
set -e

# =============================================================================
# Lab 4 — Oversharding: Cleanup
# Remove os 3 índices lab4-shard* criados pelo lab
# =============================================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Deleta um índice com tratamento de 404
delete_index() {
  local index_name="$1"
  log "Deletando índice '${index_name}'..."
  local http_code
  http_code=$(curl --silent --show-error -o /dev/null -w "%{http_code}" \
    -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
    -X DELETE "${OPENSEARCH_ENDPOINT}/${index_name}" 2>/dev/null) || true

  if [ "$http_code" = "200" ]; then
    success "Índice '${index_name}' removido com sucesso."
  elif [ "$http_code" = "404" ]; then
    warning "Índice '${index_name}' não encontrado (já foi removido ou nunca foi criado)."
  else
    error "Falha ao deletar índice '${index_name}': HTTP ${http_code}"
    exit 1
  fi
}

# =============================================================================
# Execução principal
# =============================================================================

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Lab 4 — Oversharding: Cleanup          ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

check_env

delete_index "lab4-shard1"
delete_index "lab4-shard5"
delete_index "lab4-shard20"

echo ""
success "Cleanup do Lab 4 concluído. Todos os índices lab4-shard* foram removidos."
echo ""
