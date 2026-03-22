#!/bin/bash
set -e

# =============================================================================
# Lab 3 — Diagnóstico de Latência com Profile API: Query Simples
# Executa GET /lab3-produtos/_search com "profile": true e query term simples
# =============================================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INDEX_NAME="lab3-produtos"
RESULT_FILE="/tmp/lab3-simples-result.txt"

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
echo -e "${BLUE}  Lab 3 — Profile API: Query Simples     ${NC}"
echo -e "${BLUE}  (term query + profile: true)            ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

check_env
check_connectivity

log "Executando query term simples com profile: true..."
log "Query: { \"term\": { \"status\": \"ativo\" } }"
echo ""

# Executa a query com profile: true
response=$(curl --fail --silent --show-error \
  -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X GET "${OPENSEARCH_ENDPOINT}/${INDEX_NAME}/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "profile": true,
    "query": {
      "term": { "status": "ativo" }
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

# Extrai dados do profile
query_type=$(echo "$response" | jq -r \
  '.profile.shards[0].searches[0].query[0].type' 2>/dev/null || echo "N/A")
time_in_nanos=$(echo "$response" | jq \
  '.profile.shards[0].searches[0].query[0].time_in_nanos' 2>/dev/null || echo "N/A")
description=$(echo "$response" | jq -r \
  '.profile.shards[0].searches[0].query[0].description' 2>/dev/null || echo "N/A")

# Converte nanos para milissegundos (aproximado)
if [ "$time_in_nanos" != "N/A" ] && [ "$time_in_nanos" != "null" ]; then
  time_in_ms=$(echo "$time_in_nanos" | awk '{printf "%.3f", $1/1000000}')
else
  time_in_ms="N/A"
fi

# Aviso se zero resultados — mas ainda exibe o profile
if [ "$total" = "0" ]; then
  echo -e "${YELLOW}⚠️  AVISO: A query retornou zero resultados.${NC}"
  echo -e "${YELLOW}   O profile ainda é exibido abaixo — útil para diagnóstico mesmo sem hits.${NC}"
  echo ""
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Resultado — Query Simples (Profile)    ${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "  took (total)      : ${YELLOW}${took} ms${NC}"
echo -e "  Total de hits     : ${GREEN}${total}${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${BLUE}🔬 Profile da Query:${NC}"
echo ""
echo -e "  Tipo da query     : ${YELLOW}${query_type}${NC}"
echo -e "  Descrição         : ${BLUE}${description}${NC}"
echo -e "  time_in_nanos     : ${YELLOW}${time_in_nanos} ns${NC}"
echo -e "  time_in_ms        : ${YELLOW}${time_in_ms} ms${NC}"
echo ""

# Exibe breakdown detalhado se disponível
echo -e "${BLUE}📊 Breakdown interno (tempo por operação):${NC}"
echo ""
echo "$response" | jq -r '
  .profile.shards[0].searches[0].query[0].breakdown |
  to_entries[] |
  "  \(.key): \(.value) ns"
' 2>/dev/null || warning "Breakdown não disponível."
echo ""

# Salva resultado para comparação com query complexa
echo "SIMPLES_TOOK=${took}" > "$RESULT_FILE"
echo "SIMPLES_TOTAL=${total}" >> "$RESULT_FILE"
echo "SIMPLES_TIME_NANOS=${time_in_nanos}" >> "$RESULT_FILE"
echo "SIMPLES_TIME_MS=${time_in_ms}" >> "$RESULT_FILE"
echo "SIMPLES_TYPE=${query_type}" >> "$RESULT_FILE"
success "Resultado salvo em ${RESULT_FILE} para comparação com query complexa."
echo ""

echo -e "${YELLOW}💡 Próximo passo:${NC}"
echo -e "   Execute ${BLUE}./query-complexa-profile.sh${NC} para comparar com uma query mais custosa."
echo ""
