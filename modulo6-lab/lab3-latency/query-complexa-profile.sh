#!/bin/bash
set -e

# =============================================================================
# Lab 3 — Diagnóstico de Latência com Profile API: Query Complexa
# Executa query bool (must + should + filter/range) com "profile": true
# Compara tempos de cada fase com a query simples (se disponível)
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
echo -e "${BLUE}  Lab 3 — Profile API: Query Complexa    ${NC}"
echo -e "${BLUE}  (bool + must + should + filter/range)  ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

check_env
check_connectivity

log "Executando query bool complexa com profile: true..."
log "Query: bool { must: [match descricao], should: [term status], filter: [range timestamp] }"
echo ""

# Executa a query complexa com profile: true
response=$(curl --fail --silent --show-error \
  -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X GET "${OPENSEARCH_ENDPOINT}/${INDEX_NAME}/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "profile": true,
    "query": {
      "bool": {
        "must": [
          { "match": { "descricao": "produto" } }
        ],
        "should": [
          { "term": { "status": "ativo" } },
          { "term": { "status": "pendente" } }
        ],
        "filter": [
          {
            "range": {
              "timestamp": {
                "gte": "2024-01-01T00:00:00Z",
                "lte": "2024-12-31T23:59:59Z"
              }
            }
          }
        ]
      }
    }
  }' 2>&1) || {
  error "Falha na busca. Verifique se o índice '${INDEX_NAME}' existe."
  error "Execute ./setup.sh primeiro."
  error "Detalhes: ${response}"
  exit 1
}

# Extrai métricas gerais
took=$(echo "$response" | jq '.took' 2>/dev/null || echo "N/A")
total=$(echo "$response" | jq '.hits.total.value' 2>/dev/null || echo "N/A")

# Extrai dados do profile — query raiz (BooleanQuery)
root_type=$(echo "$response" | jq -r \
  '.profile.shards[0].searches[0].query[0].type' 2>/dev/null || echo "N/A")
root_time_nanos=$(echo "$response" | jq \
  '.profile.shards[0].searches[0].query[0].time_in_nanos' 2>/dev/null || echo "N/A")

# Converte nanos para ms
if [ "$root_time_nanos" != "N/A" ] && [ "$root_time_nanos" != "null" ]; then
  root_time_ms=$(echo "$root_time_nanos" | awk '{printf "%.3f", $1/1000000}')
else
  root_time_ms="N/A"
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Resultado — Query Complexa (Profile)   ${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "  took (total)      : ${YELLOW}${took} ms${NC}"
echo -e "  Total de hits     : ${GREEN}${total}${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${BLUE}🔬 Profile da Query Raiz:${NC}"
echo ""
echo -e "  Tipo              : ${YELLOW}${root_type}${NC}"
echo -e "  time_in_nanos     : ${YELLOW}${root_time_nanos} ns${NC}"
echo -e "  time_in_ms        : ${YELLOW}${root_time_ms} ms${NC}"
echo ""

# Exibe tempo de cada sub-query (must, should, filter)
echo -e "${BLUE}📊 Tempo por fase da BooleanQuery (children):${NC}"
echo ""
echo "$response" | jq -r '
  .profile.shards[0].searches[0].query[0].children[]? |
  "  Tipo: \(.type)\n  Descrição: \(.description)\n  time_in_nanos: \(.time_in_nanos) ns\n  time_in_ms: \(.time_in_nanos / 1000000 | . * 1000 | round / 1000) ms\n  ---"
' 2>/dev/null || warning "Sub-queries (children) não disponíveis no profile."
echo ""

# Salva resultado para comparação
echo "COMPLEXA_TOOK=${took}" > "$RESULT_FILE_COMPLEXA"
echo "COMPLEXA_TOTAL=${total}" >> "$RESULT_FILE_COMPLEXA"
echo "COMPLEXA_TIME_NANOS=${root_time_nanos}" >> "$RESULT_FILE_COMPLEXA"
echo "COMPLEXA_TIME_MS=${root_time_ms}" >> "$RESULT_FILE_COMPLEXA"
echo "COMPLEXA_TYPE=${root_type}" >> "$RESULT_FILE_COMPLEXA"

# Comparação com query simples (se disponível)
if [ -f "$RESULT_FILE_SIMPLES" ]; then
  # shellcheck disable=SC1090
  source "$RESULT_FILE_SIMPLES"

  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}  Comparação: Simples vs Complexa        ${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""
  printf "  %-22s %-18s %-12s %-10s\n" "Query" "Tipo" "time_in_ms" "Hits"
  printf "  %-22s %-18s %-12s %-10s\n" "----------------------" "------------------" "------------" "----------"
  printf "  %-22s %-18s %-12s %-10s\n" "Simples (term)" "${SIMPLES_TYPE}" "${SIMPLES_TIME_MS}" "${SIMPLES_TOTAL}"
  printf "  %-22s %-18s %-12s %-10s\n" "Complexa (bool)" "${root_type}" "${root_time_ms}" "${total}"
  echo ""

  # Compara time_in_nanos numericamente
  if [ "$root_time_nanos" != "N/A" ] && [ "$root_time_nanos" != "null" ] && \
     [ "$SIMPLES_TIME_NANOS" != "N/A" ] && [ "$SIMPLES_TIME_NANOS" != "null" ]; then
    if [ "$root_time_nanos" -gt "$SIMPLES_TIME_NANOS" ] 2>/dev/null; then
      DIFF_NANOS=$((root_time_nanos - SIMPLES_TIME_NANOS))
      DIFF_MS=$(echo "$DIFF_NANOS" | awk '{printf "%.3f", $1/1000000}')
      echo -e "  🔴 Query complexa foi ${YELLOW}${DIFF_MS} ms mais lenta${NC} que a query simples."
      echo -e "     Isso é esperado: mais fases = mais tempo de execução."
    elif [ "$root_time_nanos" -lt "$SIMPLES_TIME_NANOS" ] 2>/dev/null; then
      DIFF_NANOS=$((SIMPLES_TIME_NANOS - root_time_nanos))
      DIFF_MS=$(echo "$DIFF_NANOS" | awk '{printf "%.3f", $1/1000000}')
      echo -e "  ${GREEN}✅ Query complexa foi ${DIFF_MS} ms mais rápida nesta execução.${NC}"
      echo -e "     ${YELLOW}(Pode ocorrer com datasets pequenos — execute novamente para confirmar)${NC}"
    else
      echo -e "  ⏱️  Tempos iguais nesta execução."
    fi
  fi

  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo ""
else
  warning "Resultado da query simples não encontrado em ${RESULT_FILE_SIMPLES}"
  warning "Execute ./query-simples-profile.sh primeiro para ver a comparação."
fi

echo -e "${YELLOW}💡 Por que a query complexa é mais lenta?${NC}"
echo ""
echo -e "   1. ${YELLOW}must${NC}: executa match em 'descricao' — calcula _score (BM25)"
echo -e "   2. ${YELLOW}should${NC}: executa dois term queries em 'status' — aumenta score se match"
echo -e "   3. ${YELLOW}filter${NC}: executa range em 'timestamp' — sem score, mas percorre o índice"
echo -e "   4. O OpenSearch soma o tempo de todas as fases no time_in_nanos da BooleanQuery"
echo ""
echo -e "   Use ${BLUE}_profile${NC} para identificar qual fase é o gargalo em queries lentas."
echo ""
