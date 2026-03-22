#!/bin/bash
set -e

# =============================================================================
# Lab 5 — Query Pesada Controlada: Wildcard + Aggregation
# Executa wildcard em descricao + terms aggregation em status
# Mede e exibe took + resultado da aggregation
# =============================================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INDEX_NAME="lab5-produtos"
RESULT_FILE="/tmp/lab5-wildcard-result.txt"

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
echo -e "${BLUE}  Lab 5 — Query Pesada Controlada        ${NC}"
echo -e "${BLUE}  Wildcard Query + Terms Aggregation      ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

check_env
check_connectivity

log "Executando wildcard query em 'descricao' + terms aggregation em 'status'..."
log "Query: { wildcard: { descricao: '*produto*' }, aggs: { por_status: { terms: { field: 'status' } } } }"
echo ""
warning "Esta é uma query CUSTOSA — wildcard varre todos os documentos do índice."
echo ""

# Executa a wildcard query com aggregation
response=$(curl --fail --silent --show-error \
  -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X GET "${OPENSEARCH_ENDPOINT}/${INDEX_NAME}/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "wildcard": {
        "descricao": "*produto*"
      }
    },
    "aggs": {
      "por_status": {
        "terms": {
          "field": "status"
        }
      }
    },
    "size": 0
  }' 2>&1) || {
  error "Falha na busca. Verifique se o índice '${INDEX_NAME}' existe."
  error "Execute ./setup.sh primeiro."
  error "Detalhes: ${response}"
  exit 1
}

# Extrai métricas
took=$(echo "$response" | jq '.took' 2>/dev/null || echo "N/A")
total=$(echo "$response" | jq '.hits.total.value' 2>/dev/null || echo "N/A")

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  Resultado — Wildcard + Aggregation     ${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "  took (ms)         : ${YELLOW}${took} ms${NC}"
echo -e "  Total de hits     : ${total}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Exibe resultado da aggregation
echo -e "${BLUE}📊 Aggregation por status (terms):${NC}"
echo ""
echo "$response" | jq -r '
  .aggregations.por_status.buckets[] |
  "  \(.key): \(.doc_count) documentos"
' 2>/dev/null || warning "Aggregation não disponível no response."
echo ""

# Salva resultado para comparação
echo "WILDCARD_TOOK=${took}" > "$RESULT_FILE"
echo "WILDCARD_TOTAL=${total}" >> "$RESULT_FILE"
success "Resultado salvo em ${RESULT_FILE} para comparação."

echo ""
echo -e "${YELLOW}💡 Por que wildcard é custosa?${NC}"
echo ""
echo -e "   1. ${RED}Sem uso do índice invertido${NC}: precisa varrer todos os termos do campo"
echo -e "   2. ${RED}Sem cache${NC}: wildcards com '*' no início não são cacheadas"
echo -e "   3. ${RED}Escala linear${NC}: O(n) onde n = número de documentos"
echo -e "   4. ${RED}Custo duplo${NC}: wildcard + aggregation = dois passes sobre os dados"
echo ""
echo -e "   Execute ${GREEN}./query-otimizada.sh${NC} para comparar com a abordagem eficiente."
echo ""
