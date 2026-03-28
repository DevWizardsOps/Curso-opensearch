#!/bin/bash
set -e

# =============================================================================
# Lab 0 — Criação do Ambiente OpenSearch: Testar Conexão
# Valida a conectividade com o OpenSearch Domain e exibe status do cluster
# =============================================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funções de log
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
    echo "  ./configurar-ambiente.sh"
    exit 1
  fi
}

# Testa conectividade com o cluster via /_cluster/health
check_connectivity() {
  log "Testando conexão com o OpenSearch..."
  log "Endpoint: ${OPENSEARCH_ENDPOINT}"
  echo ""

  local response
  response=$(curl --fail --silent --show-error --max-time 15 \
    -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
    "${OPENSEARCH_ENDPOINT}/_cluster/health" 2>&1) || {
    echo ""
    error "Não foi possível conectar ao OpenSearch."
    echo ""
    echo -e "${RED}--- Sugestões de Diagnóstico ---${NC}"
    echo ""
    echo "  1. O endpoint está correto?"
    echo "     Verifique o valor de OPENSEARCH_ENDPOINT:"
    echo "     ${OPENSEARCH_ENDPOINT}"
    echo ""
    echo "  2. As credenciais estão corretas?"
    echo "     Verifique OPENSEARCH_USER e OPENSEARCH_PASS."
    echo "     Reconfigure com: ./configurar-ambiente.sh"
    echo ""
    echo "  3. O Security Group permite acesso da sua EC2?"
    echo "     O domínio OpenSearch precisa permitir tráfego"
    echo "     na porta 443 a partir da sua instância EC2."
    echo ""
    echo "  4. O domínio OpenSearch está no estado 'Active'?"
    echo "     A criação leva 15-20 minutos. Verifique no console:"
    echo "     aws opensearch describe-domain --domain-name opensearch-\${ALUNO_ID}"
    echo ""
    exit 1
  }

  # Extrai informações do cluster
  local cluster_status cluster_name num_nodes num_indices
  cluster_status=$(echo "$response" | jq -r '.status' 2>/dev/null || echo "unknown")
  cluster_name=$(echo "$response" | jq -r '.cluster_name' 2>/dev/null || echo "unknown")
  num_nodes=$(echo "$response" | jq -r '.number_of_nodes' 2>/dev/null || echo "?")
  num_indices=$(echo "$response" | jq -r '.active_primary_shards' 2>/dev/null || echo "?")

  # Exibe status com cor apropriada
  local status_color
  case "$cluster_status" in
    green)  status_color="${GREEN}" ;;
    yellow) status_color="${YELLOW}" ;;
    red)    status_color="${RED}" ;;
    *)      status_color="${RED}" ;;
  esac

  echo -e "${BLUE}--- Status do Cluster ---${NC}"
  echo ""
  echo -e "  Cluster:  ${GREEN}${cluster_name}${NC}"
  echo -e "  Status:   ${status_color}${cluster_status}${NC}"
  echo -e "  Nós:      ${GREEN}${num_nodes}${NC}"
  echo -e "  Shards:   ${GREEN}${num_indices}${NC} (primary shards ativos)"
  echo ""

  # Avalia status do cluster
  case "$cluster_status" in
    green)
      success "Cluster saudável — status GREEN."
      ;;
    yellow)
      warning "Cluster com status YELLOW — réplicas podem não estar alocadas."
      warning "Isso é normal para clusters de nó único (t3.small.search)."
      ;;
    red)
      warning "Cluster com status RED — alguns shards não estão alocados."
      warning "O cluster pode estar inicializando. Aguarde alguns minutos e tente novamente."
      ;;
    *)
      warning "Status desconhecido: ${cluster_status}"
      ;;
  esac
}

# Testa acesso ao OpenSearch Dashboards
check_dashboards() {
  log "Verificando acesso ao OpenSearch Dashboards..."

  local http_code
  http_code=$(curl --silent --output /dev/null --write-out "%{http_code}" --max-time 10 \
    -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
    "${OPENSEARCH_ENDPOINT}/_dashboards" 2>/dev/null) || http_code="000"

  if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 400 ]; then
    success "OpenSearch Dashboards acessível (HTTP ${http_code})."
  else
    warning "OpenSearch Dashboards não acessível (HTTP ${http_code})."
    warning "O Dashboards pode não estar habilitado ou o endpoint pode ser diferente."
  fi
}

# =============================================================================
# Execução principal
# =============================================================================

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Lab 0 — Testar Conexão OpenSearch      ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Passo 1: Verificar variáveis de ambiente
check_env
success "Variáveis de ambiente configuradas."
echo ""

# Passo 2: Testar conectividade com o cluster
check_connectivity
echo ""

# Passo 3: Testar acesso ao Dashboards
check_dashboards
echo ""

# Resultado final
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Ambiente Pronto para os Labs!          ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Próximo passo: inicie o Lab 1 — Bulk Indexing"
echo -e "  ${BLUE}cd ../lab1-bulk/${NC}"
echo -e "  ${BLUE}./setup.sh${NC}"
echo ""

success "Teste de conexão finalizado."
echo ""
