#!/bin/bash
set -e

# =============================================================================
# Lab 6 — Monitoramento do Cluster: Monitorar Tudo
# Executa cluster-health.sh, cat-nodes.sh e cat-indices.sh em sequência
# com separadores visuais entre cada seção
# =============================================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Separador visual entre seções
separator() {
  echo ""
  echo -e "${BLUE}################################################################${NC}"
  echo -e "${BLUE}##  $1"
  echo -e "${BLUE}################################################################${NC}"
  echo ""
}

# =============================================================================
# Execução principal
# =============================================================================

echo ""
echo -e "${BLUE}################################################################${NC}"
echo -e "${BLUE}##                                                            ##${NC}"
echo -e "${BLUE}##   Lab 6 — Monitoramento Completo do Cluster OpenSearch    ##${NC}"
echo -e "${BLUE}##                                                            ##${NC}"
echo -e "${BLUE}################################################################${NC}"
echo ""
echo -e "  Endpoint : ${OPENSEARCH_ENDPOINT:-'(não definido)'}"
echo -e "  Data/Hora: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

check_env
check_connectivity

# ============================================================
# SEÇÃO 1: Cluster Health
# ============================================================
separator "SEÇÃO 1/3 — Saúde do Cluster (_cluster/health)"

# Executa cluster-health.sh — captura exit code sem abortar o script
HEALTH_EXIT=0
bash "${SCRIPT_DIR}/cluster-health.sh" || HEALTH_EXIT=$?

# ============================================================
# SEÇÃO 2: Nós do Cluster
# ============================================================
separator "SEÇÃO 2/3 — Nós do Cluster (_cat/nodes)"

bash "${SCRIPT_DIR}/cat-nodes.sh"

# ============================================================
# SEÇÃO 3: Índices do Cluster
# ============================================================
separator "SEÇÃO 3/3 — Índices do Cluster (_cat/indices)"

bash "${SCRIPT_DIR}/cat-indices.sh"

# ============================================================
# Resumo final
# ============================================================
echo ""
echo -e "${BLUE}################################################################${NC}"
echo -e "${BLUE}##  Monitoramento Concluído                                   ##${NC}"
echo -e "${BLUE}################################################################${NC}"
echo ""
echo -e "  Scripts executados: cluster-health.sh, cat-nodes.sh, cat-indices.sh"
echo -e "  Data/Hora: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Propaga exit code do cluster-health se foi red (exit 1)
if [ "$HEALTH_EXIT" -ne 0 ]; then
  error "Cluster em estado RED — verifique os alertas acima."
  exit 1
fi

success "Monitoramento concluído sem alertas críticos."
echo ""
