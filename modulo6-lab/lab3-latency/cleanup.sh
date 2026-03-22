#!/bin/bash
set -e

# =============================================================================
# Lab 3 — Diagnóstico de Latência com Profile API: Cleanup
# Remove o índice lab3-produtos e arquivos temporários
# =============================================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INDEX_NAME="lab3-produtos"
RESULT_FILE_SIMPLES="/tmp/lab3-simples-result.txt"
RESULT_FILE_COMPLEXA="/tmp/lab3-complexa-result.txt"

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

# =============================================================================
# Execução principal
# =============================================================================

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Lab 3 — Diagnóstico de Latência        ${NC}"
echo -e "${BLUE}  Cleanup                                ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

check_env

# Deleta o índice lab3-produtos
log "Deletando índice '${INDEX_NAME}'..."
http_code=$(curl --silent --show-error -o /dev/null -w "%{http_code}" \
  -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X DELETE "${OPENSEARCH_ENDPOINT}/${INDEX_NAME}" 2>/dev/null) || true

if [ "$http_code" = "200" ]; then
  success "Índice '${INDEX_NAME}' removido com sucesso."
elif [ "$http_code" = "404" ]; then
  warning "Índice '${INDEX_NAME}' não encontrado (já foi removido ou nunca foi criado)."
else
  error "Falha ao deletar índice '${INDEX_NAME}': HTTP ${http_code}"
  exit 1
fi

# Remove arquivos de resultado temporários
for result_file in "$RESULT_FILE_SIMPLES" "$RESULT_FILE_COMPLEXA"; do
  if [ -f "$result_file" ]; then
    rm -f "$result_file"
    success "Arquivo temporário '${result_file}' removido."
  else
    log "Arquivo temporário '${result_file}' não encontrado (nenhuma ação necessária)."
  fi
done

echo ""
success "Cleanup do Lab 3 concluído. Todos os recursos foram removidos."
echo ""
