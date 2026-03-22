#!/bin/bash
set -e

# =============================================================================
# Lab 6 — Monitoramento do Cluster: Cluster Health
# GET /_cluster/health?pretty com destaque de status por cores
# Alerta se red ou yellow; encerra com exit 1 se red
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
  success "Cluster acessível."
}

# =============================================================================
# Execução principal
# =============================================================================

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Lab 6 — Monitoramento do Cluster       ${NC}"
echo -e "${BLUE}  Cluster Health                         ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

check_env
check_connectivity

log "Consultando GET /_cluster/health?pretty..."
echo ""

# Busca health completo
response=$(curl --fail --silent --show-error \
  -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  "${OPENSEARCH_ENDPOINT}/_cluster/health?pretty" 2>&1) || {
  error "Falha ao consultar _cluster/health"
  error "Detalhes: ${response}"
  exit 1
}

# Extrai campos principais
cluster_name=$(echo "$response" | jq -r '.cluster_name' 2>/dev/null || echo "N/A")
status=$(echo "$response" | jq -r '.status' 2>/dev/null || echo "unknown")
nodes=$(echo "$response" | jq -r '.number_of_nodes' 2>/dev/null || echo "N/A")
data_nodes=$(echo "$response" | jq -r '.number_of_data_nodes' 2>/dev/null || echo "N/A")
active_shards=$(echo "$response" | jq -r '.active_shards' 2>/dev/null || echo "N/A")
active_primary=$(echo "$response" | jq -r '.active_primary_shards' 2>/dev/null || echo "N/A")
unassigned=$(echo "$response" | jq -r '.unassigned_shards' 2>/dev/null || echo "N/A")
relocating=$(echo "$response" | jq -r '.relocating_shards' 2>/dev/null || echo "N/A")
initializing=$(echo "$response" | jq -r '.initializing_shards' 2>/dev/null || echo "N/A")

# Determina cor e ícone do status
case "$status" in
  green)
    STATUS_COLOR="${GREEN}"
    STATUS_ICON="🟢"
    ;;
  yellow)
    STATUS_COLOR="${YELLOW}"
    STATUS_ICON="🟡"
    ;;
  red)
    STATUS_COLOR="${RED}"
    STATUS_ICON="🔴"
    ;;
  *)
    STATUS_COLOR="${BLUE}"
    STATUS_ICON="⚪"
    ;;
esac

echo -e "${STATUS_COLOR}========================================${NC}"
echo -e "${STATUS_COLOR}  ${STATUS_ICON} Cluster Health: ${status^^}${NC}"
echo -e "${STATUS_COLOR}========================================${NC}"
echo ""
echo -e "  Cluster           : ${cluster_name}"
echo -e "  Status            : ${STATUS_COLOR}${status}${NC}"
echo -e "  Nós totais        : ${nodes}"
echo -e "  Nós de dados      : ${data_nodes}"
echo -e "  Shards ativos     : ${active_shards}"
echo -e "  Shards primários  : ${active_primary}"
echo -e "  Shards não alocados: ${unassigned}"
echo -e "  Shards realocando : ${relocating}"
echo -e "  Shards inicializando: ${initializing}"
echo ""

# Alertas por status
case "$status" in
  green)
    success "Cluster saudável — todos os shards estão alocados e ativos."
    ;;
  yellow)
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  ⚠️  AVISO: Cluster em estado YELLOW     ${NC}"
    echo -e "${YELLOW}========================================${NC}"
    warning "Shards primários OK, mas réplicas não estão alocadas."
    warning "Causa comum: cluster com apenas 1 nó (réplicas não podem ser alocadas no mesmo nó)."
    warning "Ação: verifique com GET /_cat/shards?v para identificar shards UNASSIGNED."
    echo ""
    ;;
  red)
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}  🚨 CRÍTICO: Cluster em estado RED       ${NC}"
    echo -e "${RED}========================================${NC}"
    error "Um ou mais shards PRIMÁRIOS não estão alocados!"
    error "Dados podem estar inacessíveis. Ação imediata necessária."
    error "Verifique: GET /_cat/shards?v para identificar shards UNASSIGNED"
    error "Verifique: GET /_cluster/allocation/explain para diagnóstico detalhado"
    echo ""
    exit 1
    ;;
esac

echo ""
log "Response completo do _cluster/health:"
echo ""
echo "$response"
echo ""
