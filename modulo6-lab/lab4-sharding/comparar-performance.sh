#!/bin/bash
set -e

# =============================================================================
# Lab 4 — Oversharding: Comparar Performance
# Executa match_all em cada índice e exibe tabela comparativa de took (ms)
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

# Executa match_all em um índice e retorna took + doc count
query_index() {
  local index_name="$1"

  local response
  response=$(curl --silent --show-error \
    -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
    -X GET "${OPENSEARCH_ENDPOINT}/${index_name}/_search" \
    -H "Content-Type: application/json" \
    -d '{"query": {"match_all": {}}, "size": 0}' 2>/dev/null) || {
    echo "ERROR"
    return 1
  }

  local took
  took=$(echo "$response" | jq '.took' 2>/dev/null || echo "N/A")
  local docs
  docs=$(echo "$response" | jq '.hits.total.value' 2>/dev/null || echo "N/A")

  echo "${took}|${docs}"
}

# =============================================================================
# Execução principal
# =============================================================================

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Lab 4 — Oversharding                   ${NC}"
echo -e "${BLUE}  Comparação de Performance (match_all)   ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

check_env
check_connectivity

echo ""
log "Executando match_all em cada índice (3 execuções para estabilizar cache)..."
echo ""

# Arrays para armazenar resultados
declare -a INDICES=("lab4-shard1" "lab4-shard5" "lab4-shard20")
declare -a SHARDS=("1" "5" "20")
declare -a TOOKS=()
declare -a DOCS=()

for i in "${!INDICES[@]}"; do
  idx="${INDICES[$i]}"

  # Verifica se o índice existe
  http_code=$(curl --silent -o /dev/null -w "%{http_code}" \
    -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
    "${OPENSEARCH_ENDPOINT}/${idx}" 2>/dev/null) || true

  if [ "$http_code" != "200" ]; then
    warning "Índice '${idx}' não encontrado. Execute ./criar-indices-shards.sh primeiro."
    TOOKS+=("N/A")
    DOCS+=("N/A")
    continue
  fi

  # Executa 3 vezes e pega a última (para estabilizar cache)
  result="N/A|N/A"
  for run in 1 2 3; do
    result=$(query_index "$idx") || true
  done

  took=$(echo "$result" | cut -d'|' -f1)
  docs=$(echo "$result" | cut -d'|' -f2)

  TOOKS+=("${took}")
  DOCS+=("${docs}")

  log "  ${idx}: took=${took}ms, docs=${docs}"
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Tabela Comparativa — match_all          ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
printf "  %-20s %-8s %-12s %-10s\n" "Índice" "Shards" "took (ms)" "Docs"
printf "  %-20s %-8s %-12s %-10s\n" "--------------------" "--------" "------------" "----------"

for i in "${!INDICES[@]}"; do
  printf "  %-20s %-8s %-12s %-10s\n" \
    "${INDICES[$i]}" "${SHARDS[$i]}" "${TOOKS[$i]}" "${DOCS[$i]}"
done

echo ""
echo -e "${YELLOW}💡 Interpretação dos resultados:${NC}"
echo ""
echo -e "   • Para datasets pequenos (100 docs), ${GREEN}1 shard é mais eficiente${NC}"
echo -e "   • Com mais shards, o OpenSearch precisa coordenar respostas de cada shard"
echo -e "   • O overhead de coordenação supera o benefício do paralelismo em dados pequenos"
echo -e "   • Em produção com GBs de dados, mais shards podem melhorar a performance"
echo ""
echo -e "   Regra geral: ${YELLOW}10-50 GB por shard${NC} é o tamanho ideal"
echo ""
