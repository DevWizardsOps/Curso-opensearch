#!/bin/bash
set -e

# =============================================================================
# Lab 1 — Bulk Indexing: Ingestão Bulk
# Envia todos os documentos em uma única requisição POST /_bulk
# =============================================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INDEX_NAME="lab1-produtos"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATASET_PATH="${SCRIPT_DIR}/../dataset/dataset.json"
RESULT_FILE_INDIVIDUAL="/tmp/lab1-individual-result.txt"

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

# Limpa o índice e recria para comparação justa
reset_index() {
  log "Limpando índice '${INDEX_NAME}' para comparação justa..."

  # Deleta o índice se existir
  local http_code
  http_code=$(curl --silent --show-error -o /dev/null -w "%{http_code}" \
    -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
    -X DELETE "${OPENSEARCH_ENDPOINT}/${INDEX_NAME}" 2>/dev/null) || true

  if [ "$http_code" = "200" ]; then
    success "Índice '${INDEX_NAME}' removido."
  elif [ "$http_code" = "404" ]; then
    log "Índice '${INDEX_NAME}' não existia."
  else
    warning "Resposta inesperada ao deletar índice: HTTP ${http_code}"
  fi

  # Recria via setup.sh
  bash "${SCRIPT_DIR}/setup.sh"
}

# =============================================================================
# Execução principal
# =============================================================================

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Lab 1 — Ingestão Bulk                  ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

check_env

# Verifica dataset
if [ ! -f "$DATASET_PATH" ]; then
  error "Dataset não encontrado em ${DATASET_PATH}"
  error "Certifique-se de que o dataset foi criado em modulo6-lab/dataset/dataset.json"
  exit 1
fi

# Conta documentos (linhas pares = documentos)
TOTAL=$(awk 'NR%2==0' "$DATASET_PATH" | wc -l | tr -d ' ')

log "Dataset: ${DATASET_PATH}"
log "Total de documentos a enviar: ${TOTAL}"

# Limpa e recria o índice para comparação justa
reset_index

log "Iniciando ingestão bulk..."
echo ""

# Marca tempo de início (nanosegundos)
START_NS=$(date +%s%N)

# Envia todos os documentos em uma única requisição _bulk
# O dataset.json já está no formato bulk (linha de ação + linha de documento)
response=$(curl --fail --silent --show-error \
  -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X POST "${OPENSEARCH_ENDPOINT}/_bulk" \
  -H "Content-Type: application/json" \
  --data-binary "@${DATASET_PATH}" 2>&1) || {
  error "Falha na requisição bulk"
  error "Detalhes: ${response}"
  exit 1
}

# Marca tempo de fim (nanosegundos)
END_NS=$(date +%s%N)

# Verifica erros no response bulk
ERRORS=$(echo "$response" | jq '.errors' 2>/dev/null || echo "false")
if [ "$ERRORS" = "true" ]; then
  warning "Alguns documentos tiveram erros durante a ingestão bulk."
  FAILED=$(echo "$response" | jq '[.items[] | select(.index.error != null)] | length' 2>/dev/null || echo "?")
  warning "Documentos com erro: ${FAILED}"
fi

# Calcula tempo total em segundos (com decimais via awk)
ELAPSED_NS=$((END_NS - START_NS))
ELAPSED_S=$(awk "BEGIN { printf \"%.3f\", ${ELAPSED_NS} / 1000000000 }")
DOCS_PER_SEC=$(awk "BEGIN { if (${ELAPSED_S} > 0) printf \"%.1f\", ${TOTAL} / ${ELAPSED_S}; else print \"N/A\" }")

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Resultado — Ingestão Bulk              ${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "  Documentos enviados : ${GREEN}${TOTAL}${NC}"
echo -e "  Tempo total         : ${YELLOW}${ELAPSED_S} segundos${NC}"
echo -e "  Taxa de ingestão    : ${YELLOW}${DOCS_PER_SEC} docs/segundo${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Comparação automática com ingestão individual (se disponível)
if [ -f "$RESULT_FILE_INDIVIDUAL" ]; then
  # shellcheck disable=SC1090
  source "$RESULT_FILE_INDIVIDUAL"

  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}  Comparação: Individual vs Bulk         ${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""
  printf "  %-22s %-15s %-15s\n" "Método" "Tempo (s)" "Docs/segundo"
  printf "  %-22s %-15s %-15s\n" "----------------------" "---------------" "---------------"
  printf "  %-22s %-15s %-15s\n" "Individual" "${TEMPO_S}" "${DOCS_POR_SEGUNDO}"
  printf "  %-22s %-15s %-15s\n" "Bulk" "${ELAPSED_S}" "${DOCS_PER_SEC}"
  echo ""

  # Calcula speedup
  SPEEDUP=$(awk "BEGIN {
    t_ind = ${TEMPO_S}
    t_bulk = ${ELAPSED_S}
    if (t_bulk > 0 && t_ind > 0) printf \"%.1f\", t_ind / t_bulk
    else print \"N/A\"
  }")

  if [ "$SPEEDUP" != "N/A" ]; then
    echo -e "  🚀 Bulk foi ${GREEN}${SPEEDUP}x mais rápido${NC} que a ingestão individual!"
  fi
  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo ""
else
  warning "Resultado da ingestão individual não encontrado em ${RESULT_FILE_INDIVIDUAL}"
  warning "Execute ingestao-individual.sh primeiro para ver a comparação."
fi

success "Ingestão bulk concluída."
echo ""
