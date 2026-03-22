#!/bin/bash
set -e

# =============================================================================
# Lab 6 — Monitoramento do Cluster: Cat Indices
# GET /_cat/indices?v&s=store.size:desc — ordenado por tamanho decrescente
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
echo -e "${BLUE}  Índices do Cluster (_cat/indices)       ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

check_env
check_connectivity

log "Consultando GET /_cat/indices?v&s=store.size:desc (ordenado por tamanho)..."
echo ""

# Busca lista de índices ordenada por tamanho
response=$(curl --fail --silent --show-error \
  -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  "${OPENSEARCH_ENDPOINT}/_cat/indices?v&s=store.size:desc" 2>&1) || {
  error "Falha ao consultar _cat/indices"
  error "Detalhes: ${response}"
  exit 1
}

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Índices (ordenados por tamanho)         ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "$response"
echo ""

# Conta índices por status de saúde
total_indices=$(echo "$response" | grep -v "^health" | grep -c "." 2>/dev/null || echo "0")
green_count=$(echo "$response" | grep -c "^green" 2>/dev/null || echo "0")
yellow_count=$(echo "$response" | grep -c "^yellow" 2>/dev/null || echo "0")
red_count=$(echo "$response" | grep -c "^red" 2>/dev/null || echo "0")

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Resumo de Saúde dos Índices             ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "  Total de índices  : ${total_indices}"
echo -e "  🟢 green          : ${green_count}"
echo -e "  🟡 yellow         : ${yellow_count}"
echo -e "  🔴 red            : ${red_count}"
echo ""

# Alertas para índices red
if [ "$red_count" -gt 0 ] 2>/dev/null; then
  echo -e "${RED}⚠️  Índices em estado RED (dados potencialmente inacessíveis):${NC}"
  echo "$response" | grep "^red" | awk '{print "   " $3}' 2>/dev/null || true
  echo ""
fi

# Alertas para índices yellow
if [ "$yellow_count" -gt 0 ] 2>/dev/null; then
  echo -e "${YELLOW}ℹ️  Índices em estado YELLOW (réplicas não alocadas):${NC}"
  echo "$response" | grep "^yellow" | awk '{print "   " $3}' 2>/dev/null || true
  echo -e "   ${YELLOW}(Normal em cluster de 1 nó com number_of_replicas > 0)${NC}"
  echo ""
fi

echo -e "${YELLOW}💡 Legenda:${NC}"
echo -e "   health: ${GREEN}green${NC} = OK, ${YELLOW}yellow${NC} = réplicas não alocadas, ${RED}red${NC} = shards primários ausentes"
echo -e "   store.size: tamanho total (primários + réplicas)"
echo -e "   pri.store.size: tamanho apenas dos shards primários"
echo -e "   docs.count: documentos indexados (excluindo deletados)"
echo -e "   docs.deleted: documentos marcados para deleção (aguardando merge)"
echo ""
