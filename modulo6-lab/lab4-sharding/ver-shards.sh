#!/bin/bash
set -e

# =============================================================================
# Lab 4 — Oversharding: Ver Shards
# Exibe distribuição de shards dos índices lab4-shard* via _cat/shards
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

# =============================================================================
# Execução principal
# =============================================================================

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Lab 4 — Oversharding                   ${NC}"
echo -e "${BLUE}  Distribuição de Shards (_cat/shards)    ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

check_env
check_connectivity

echo ""
log "Consultando _cat/shards para índices lab4-shard*..."
echo ""

# Busca shards dos índices lab4-shard*
response=$(curl --fail --silent --show-error \
  -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  "${OPENSEARCH_ENDPOINT}/_cat/shards/lab4-shard*?v&h=index,shard,prirep,state,docs,store,node" 2>&1) || {
  error "Falha ao consultar _cat/shards"
  error "Detalhes: ${response}"
  exit 1
}

if [ -z "$response" ] || echo "$response" | grep -q "^index"; then
  if [ -z "$(echo "$response" | grep -v '^index')" ]; then
    warning "Nenhum índice lab4-shard* encontrado."
    warning "Execute ./criar-indices-shards.sh primeiro."
    exit 0
  fi
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Shards dos índices lab4-shard*          ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "$response"
echo ""

# Resumo por índice
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Resumo por índice                       ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

for idx in lab4-shard1 lab4-shard5 lab4-shard20; do
  shard_count=$(echo "$response" | grep "^${idx}" | grep -c "p" 2>/dev/null || echo "0")
  total_docs=$(echo "$response" | grep "^${idx}" | grep "p" | awk '{sum += $5} END {print sum+0}' 2>/dev/null || echo "0")
  printf "  %-20s shards primários: %-4s docs totais: %s\n" "${idx}" "${shard_count}" "${total_docs}"
done

echo ""
echo -e "${YELLOW}💡 Legenda:${NC}"
echo -e "   prirep: ${GREEN}p${NC} = shard primário, ${YELLOW}r${NC} = réplica"
echo -e "   state:  ${GREEN}STARTED${NC} = ativo, ${YELLOW}INITIALIZING${NC} = inicializando, ${RED}UNASSIGNED${NC} = não alocado"
echo -e "   store:  tamanho em disco do shard"
echo ""
echo -e "   Observe como o índice com 20 shards tem ${YELLOW}20 entradas${NC} vs ${GREEN}1 entrada${NC} do índice com 1 shard"
echo -e "   para o mesmo volume de dados — isso é o overhead do oversharding."
echo ""
