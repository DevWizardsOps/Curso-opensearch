#!/bin/bash
set -e

# =============================================================================
# Lab 2 — Filter vs Query Context: Filter Context
# Executa busca com bool.filter + term no campo status (sem cálculo de _score)
# =============================================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INDEX_NAME="lab2-produtos"
RESULT_FILE="/tmp/lab2-query-result.txt"

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

# =============================================================================
# Execução principal
# =============================================================================

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Lab 2 — Filter Context                 ${NC}"
echo -e "${BLUE}  (bool.filter + term, sem _score)        ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

check_env
check_connectivity

log "Executando busca com bool.filter + term no campo 'status' (filter context)..."
log "Query: { \"bool\": { \"filter\": [ { \"term\": { \"status\": \"ativo\" } } ] } }"
echo ""

# Executa a busca com bool.filter — filter context NÃO calcula _score
response=$(curl --fail --silent --show-error \
  -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X GET "${OPENSEARCH_ENDPOINT}/${INDEX_NAME}/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "bool": {
        "filter": [
          { "term": { "status": "ativo" } }
        ]
      }
    }
  }' 2>&1) || {
  error "Falha na busca. Verifique se o índice '${INDEX_NAME}' existe."
  error "Execute ./setup.sh primeiro."
  error "Detalhes: ${response}"
  exit 1
}

# Extrai métricas do response
took=$(echo "$response" | jq '.took' 2>/dev/null || echo "N/A")
total=$(echo "$response" | jq '.hits.total.value' 2>/dev/null || echo "N/A")

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Resultado — Filter Context             ${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "  Tempo de resposta : ${YELLOW}${took} ms${NC}"
echo -e "  Total de hits     : ${GREEN}${total}${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Comparação com query context (se resultado anterior existir)
if [ -f "$RESULT_FILE" ]; then
  # shellcheck disable=SC1090
  source "$RESULT_FILE"

  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}  Comparação: Query vs Filter Context    ${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""
  printf "  %-20s %-12s %-10s\n" "Método" "took (ms)" "Hits"
  printf "  %-20s %-12s %-10s\n" "--------------------" "------------" "----------"
  printf "  %-20s %-12s %-10s\n" "Query Context" "${QUERY_TOOK}" "${QUERY_TOTAL}"
  printf "  %-20s %-12s %-10s\n" "Filter Context" "${took}" "${total}"
  echo ""

  # Calcula diferença de tempo
  if [ "$QUERY_TOOK" != "N/A" ] && [ "$took" != "N/A" ] && \
     [ "$QUERY_TOOK" -gt 0 ] 2>/dev/null && [ "$took" -gt 0 ] 2>/dev/null; then
    if [ "$took" -lt "$QUERY_TOOK" ]; then
      DIFF=$((QUERY_TOOK - took))
      echo -e "  ⚡ Filter context foi ${GREEN}${DIFF} ms mais rápido${NC} que query context!"
    elif [ "$took" -gt "$QUERY_TOOK" ]; then
      DIFF=$((took - QUERY_TOOK))
      echo -e "  ${YELLOW}⚠️  Query context foi ${DIFF} ms mais rápido nesta execução.${NC}"
      echo -e "  ${YELLOW}   (Execute novamente — filter context aproveita cache nas próximas execuções)${NC}"
    else
      echo -e "  ⏱️  Tempos iguais nesta execução."
    fi
  fi

  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo ""
else
  warning "Resultado do query context não encontrado em ${RESULT_FILE}"
  warning "Execute ./query-context.sh primeiro para ver a comparação."
fi

echo -e "${YELLOW}💡 Por que filter context é mais eficiente?${NC}"
echo ""
echo -e "   1. ${GREEN}Sem cálculo de _score${NC}: não executa BM25 nem algoritmos de relevância"
echo -e "   2. ${GREEN}Cache de filtros${NC}: o OpenSearch armazena o resultado em bitset cache"
echo -e "      e reutiliza em consultas subsequentes idênticas"
echo -e "   3. ${GREEN}Menos CPU${NC}: operação binária (sim/não) vs operação de pontuação (float)"
echo ""
echo -e "   Use filter context para: status, IDs, datas, ranges numéricos"
echo -e "   Use query context para: busca full-text onde relevância importa"
echo ""
