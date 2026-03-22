#!/bin/bash
set -e

# =============================================================================
# Lab 5 — Query Pesada Controlada: Query Otimizada
# Executa term em status.keyword + terms aggregation em status
# Compara com resultado da wildcard se disponível
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
echo -e "${BLUE}  Query Otimizada: term + Aggregation     ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

check_env
check_connectivity

log "Executando term query em 'status' + terms aggregation (query otimizada)..."
log "Query: { term: { status: 'ativo' }, aggs: { por_status: { terms: { field: 'status' } } } }"
echo ""
success "Esta é uma query EFICIENTE — term usa o índice invertido diretamente."
echo ""

# Executa a query otimizada com aggregation
response=$(curl --fail --silent --show-error \
  -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X GET "${OPENSEARCH_ENDPOINT}/${INDEX_NAME}/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "term": {
        "status": "ativo"
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

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Resultado — Query Otimizada             ${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "  took (ms)         : ${GREEN}${took} ms${NC}"
echo -e "  Total de hits     : ${total}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Exibe resultado da aggregation
echo -e "${BLUE}📊 Aggregation por status (terms):${NC}"
echo ""
echo "$response" | jq -r '
  .aggregations.por_status.buckets[] |
  "  \(.key): \(.doc_count) documentos"
' 2>/dev/null || warning "Aggregation não disponível no response."
echo ""

# Comparação com wildcard (se resultado anterior existir)
if [ -f "$RESULT_FILE" ]; then
  # shellcheck disable=SC1090
  source "$RESULT_FILE"

  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}  Comparação: Wildcard vs Otimizada       ${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""
  printf "  %-30s %-12s %-10s\n" "Query" "took (ms)" "Hits"
  printf "  %-30s %-12s %-10s\n" "------------------------------" "------------" "----------"
  printf "  %-30s %-12s %-10s\n" "Wildcard (*produto*) + agg" "${WILDCARD_TOOK}" "${WILDCARD_TOTAL}"
  printf "  %-30s %-12s %-10s\n" "Term (status=ativo) + agg" "${took}" "${total}"
  echo ""

  # Calcula diferença de tempo
  if [ "$WILDCARD_TOOK" != "N/A" ] && [ "$took" != "N/A" ] && \
     [ "$WILDCARD_TOOK" -gt 0 ] 2>/dev/null && [ "$took" -gt 0 ] 2>/dev/null; then
    if [ "$took" -lt "$WILDCARD_TOOK" ]; then
      DIFF=$((WILDCARD_TOOK - took))
      echo -e "  ⚡ Query otimizada foi ${GREEN}${DIFF} ms mais rápida${NC} que a wildcard!"
    elif [ "$took" -gt "$WILDCARD_TOOK" ]; then
      DIFF=$((took - WILDCARD_TOOK))
      echo -e "  ${YELLOW}⚠️  Wildcard foi ${DIFF} ms mais rápida nesta execução.${NC}"
      echo -e "  ${YELLOW}   (Pode ocorrer com datasets pequenos ou cache aquecido — execute novamente)${NC}"
    else
      echo -e "  ⏱️  Tempos iguais nesta execução."
    fi
  fi

  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo ""
else
  warning "Resultado da wildcard não encontrado em ${RESULT_FILE}"
  warning "Execute ./query-wildcard-agg.sh primeiro para ver a comparação."
fi

echo -e "${GREEN}💡 Por que term query é mais eficiente?${NC}"
echo ""
echo -e "   1. ${GREEN}Índice invertido${NC}: lookup direto O(1) — não varre todos os documentos"
echo -e "   2. ${GREEN}Filter cache${NC}: o resultado é cacheado e reutilizado em queries idênticas"
echo -e "   3. ${GREEN}Sem score${NC}: operação binária (sim/não) — sem cálculo de relevância"
echo -e "   4. ${GREEN}Escala constante${NC}: performance não degrada com volume de dados"
echo ""
echo -e "   Use ${GREEN}term${NC} para filtros exatos em campos keyword (status, id, categoria)"
echo -e "   Use ${RED}wildcard${NC} apenas quando absolutamente necessário e com prefixo fixo"
echo ""
