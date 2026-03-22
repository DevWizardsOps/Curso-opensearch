#!/bin/bash
set -e

# =============================================================================
# Lab 6 — Monitoramento do Cluster: Cat Nodes
# GET /_cat/nodes?v com métricas de recursos de cada nó
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
echo -e "${BLUE}  Lab 6 — Monitoramento do Cluster       ${NC}"
echo -e "${BLUE}  Nós do Cluster (_cat/nodes)             ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

check_env
check_connectivity

log "Consultando GET /_cat/nodes?v&h=name,ip,heap.percent,ram.percent,cpu,load_1m,node.role..."
echo ""

# Busca informações dos nós
response=$(curl --fail --silent --show-error \
  -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  "${OPENSEARCH_ENDPOINT}/_cat/nodes?v&h=name,ip,heap.percent,ram.percent,cpu,load_1m,node.role" 2>&1) || {
  error "Falha ao consultar _cat/nodes"
  error "Detalhes: ${response}"
  exit 1
}

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Nós do Cluster                         ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "$response"
echo ""

# Alertas baseados em heap.percent
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Análise de Recursos                    ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Verifica heap alto (> 75%)
high_heap=$(echo "$response" | awk 'NR>1 && $3+0 > 75 {print $1, $3"%"}' 2>/dev/null || true)
if [ -n "$high_heap" ]; then
  echo -e "${RED}⚠️  Nós com heap > 75% (risco de GC pressure):${NC}"
  echo "$high_heap" | while read -r line; do
    echo -e "   ${RED}${line}${NC}"
  done
  echo ""
else
  success "Heap dentro do limite em todos os nós (< 75%)."
fi

# Verifica CPU alto (> 80%)
high_cpu=$(echo "$response" | awk 'NR>1 && $5+0 > 80 {print $1, $5"%"}' 2>/dev/null || true)
if [ -n "$high_cpu" ]; then
  echo -e "${YELLOW}⚠️  Nós com CPU > 80%:${NC}"
  echo "$high_cpu" | while read -r line; do
    echo -e "   ${YELLOW}${line}${NC}"
  done
  echo ""
else
  success "CPU dentro do limite em todos os nós (< 80%)."
fi

echo ""
echo -e "${YELLOW}💡 Legenda de node.role:${NC}"
echo -e "   ${GREEN}m${NC} = master eligible   ${GREEN}d${NC} = data node"
echo -e "   ${GREEN}i${NC} = ingest node       ${GREEN}r${NC} = remote cluster client"
echo -e "   ${GREEN}*${NC} = master atual"
echo ""
echo -e "${YELLOW}💡 Thresholds de alerta:${NC}"
echo -e "   heap.percent > 75%: risco de GC pressure e OutOfMemoryError"
echo -e "   cpu > 80%: cluster sobrecarregado — considere escalar"
echo -e "   load_1m > nCPUs: sistema saturado"
echo ""
