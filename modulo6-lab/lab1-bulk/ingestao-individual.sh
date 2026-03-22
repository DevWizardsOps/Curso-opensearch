#!/bin/bash
set -e

# =============================================================================
# Lab 1 — Bulk Indexing: Ingestão Individual
# Envia cada documento individualmente via POST /{index}/_doc
# =============================================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INDEX_NAME="lab1-produtos"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATASET_PATH="${SCRIPT_DIR}/../../dataset/dataset.json"
RESULT_FILE="/tmp/lab1-individual-result.txt"

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

# Verifica se o índice existe; se não, chama setup.sh
ensure_index() {
  local exists
  exists=$(curl --fail --silent --show-error -o /dev/null -w "%{http_code}" \
    -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
    "${OPENSEARCH_ENDPOINT}/${INDEX_NAME}" 2>/dev/null) || true

  if [ "$exists" != "200" ]; then
    warning "Índice '${INDEX_NAME}' não encontrado. Executando setup.sh..."
    bash "${SCRIPT_DIR}/setup.sh"
  fi
}

# =============================================================================
# Execução principal
# =============================================================================

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Lab 1 — Ingestão Individual            ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

check_env

# Verifica dataset
if [ ! -f "$DATASET_PATH" ]; then
  error "Dataset não encontrado em ${DATASET_PATH}"
  error "Certifique-se de que o dataset foi criado em modulo6-lab/dataset/dataset.json"
  exit 1
fi

ensure_index

# Extrai apenas as linhas de documento (linhas pares — os documentos em si)
# O formato bulk tem: linha ímpar = ação {"index":{...}}, linha par = documento
DOCS=$(awk 'NR%2==0' "$DATASET_PATH")
TOTAL=$(echo "$DOCS" | wc -l | tr -d ' ')

log "Dataset: ${DATASET_PATH}"
log "Total de documentos a enviar: ${TOTAL}"
log "Iniciando ingestão individual..."
echo ""

# Marca tempo de início (nanosegundos)
START_NS=$(date +%s%N)

COUNT=0
ERRORS=0

while IFS= read -r doc; do
  [ -z "$doc" ] && continue

  response=$(curl --fail --silent --show-error \
    -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
    -X POST "${OPENSEARCH_ENDPOINT}/${INDEX_NAME}/_doc" \
    -H "Content-Type: application/json" \
    -d "$doc" 2>&1) || {
    ERRORS=$((ERRORS + 1))
    warning "Falha ao enviar documento #$((COUNT + 1)): ${response}"
    continue
  }

  COUNT=$((COUNT + 1))

  # Progresso a cada 10 documentos
  if [ $((COUNT % 10)) -eq 0 ]; then
    echo -ne "\r${BLUE}[INFO]${NC} Enviados: ${COUNT}/${TOTAL}..."
  fi
done <<< "$DOCS"

echo ""

# Marca tempo de fim (nanosegundos)
END_NS=$(date +%s%N)

# Calcula tempo total em segundos (com decimais via awk)
ELAPSED_NS=$((END_NS - START_NS))
ELAPSED_S=$(awk "BEGIN { printf \"%.3f\", ${ELAPSED_NS} / 1000000000 }")
DOCS_PER_SEC=$(awk "BEGIN { if (${ELAPSED_S} > 0) printf \"%.1f\", ${COUNT} / ${ELAPSED_S}; else print \"N/A\" }")

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Resultado — Ingestão Individual        ${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "  Documentos enviados : ${GREEN}${COUNT}${NC}"
if [ "$ERRORS" -gt 0 ]; then
  echo -e "  Erros               : ${RED}${ERRORS}${NC}"
fi
echo -e "  Tempo total         : ${YELLOW}${ELAPSED_S} segundos${NC}"
echo -e "  Taxa de ingestão    : ${YELLOW}${DOCS_PER_SEC} docs/segundo${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Salva resultado para comparação posterior
cat > "$RESULT_FILE" <<EOF
METODO=individual
DOCS=${COUNT}
TEMPO_S=${ELAPSED_S}
DOCS_POR_SEGUNDO=${DOCS_PER_SEC}
EOF

success "Resultado salvo em ${RESULT_FILE} para comparação com ingestão bulk."
echo ""
