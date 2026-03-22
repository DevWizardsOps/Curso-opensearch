#!/bin/bash
set -e

# =============================================================================
# Preparação do Curso — Teste do Ambiente
# Valida que o ambiente OpenSearch está funcional e acessível
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

# Parse de argumentos
ENDPOINT="${OPENSEARCH_ENDPOINT:-}"
USER="${OPENSEARCH_USER:-admin}"
PASS="${OPENSEARCH_PASS:-}"
PROFILE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --endpoint) ENDPOINT="$2"; shift 2 ;;
    --user)     USER="$2"; shift 2 ;;
    --pass)     PASS="$2"; shift 2 ;;
    --profile)  PROFILE="$2"; shift 2 ;;
    --help|-h)
      echo "Uso: $0 [--endpoint URL] [--user USER] [--pass PASS] [--profile PROFILE]"
      echo ""
      echo "Se não informados, usa as variáveis de ambiente:"
      echo "  OPENSEARCH_ENDPOINT, OPENSEARCH_USER, OPENSEARCH_PASS"
      exit 0
      ;;
    *) error "Argumento desconhecido: $1"; exit 1 ;;
  esac
done

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Teste do Ambiente OpenSearch            ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ============================================================
# TESTE 1: Pré-requisitos locais
# ============================================================
echo -e "${BLUE}--- Teste 1/6: Pré-requisitos locais ---${NC}"

# curl
if command -v curl &> /dev/null; then
  success "curl disponível."
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  error "curl não encontrado."
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# jq
if command -v jq &> /dev/null; then
  success "jq disponível."
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  error "jq não encontrado."
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# aws-cli
if command -v aws &> /dev/null; then
  success "aws-cli disponível."
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  warning "aws-cli não encontrado (opcional para os labs, necessário para deploy)."
  TESTS_WARNED=$((TESTS_WARNED + 1))
fi

# Variáveis de ambiente
if [ -z "$ENDPOINT" ]; then
  error "OPENSEARCH_ENDPOINT não definido. Use --endpoint ou exporte a variável."
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo ""
  echo -e "${RED}Não é possível continuar sem o endpoint.${NC}"
  echo ""
  exit 1
fi

if [ -z "$PASS" ]; then
  error "OPENSEARCH_PASS não definido. Use --pass ou exporte a variável."
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo ""
  echo -e "${RED}Não é possível continuar sem a senha.${NC}"
  echo ""
  exit 1
fi

success "Variáveis de ambiente configuradas."
TESTS_PASSED=$((TESTS_PASSED + 1))
echo ""

# ============================================================
# TESTE 2: Conectividade HTTP ao endpoint
# ============================================================
echo -e "${BLUE}--- Teste 2/6: Conectividade HTTP ---${NC}"

http_code=$(curl --silent -o /dev/null -w "%{http_code}" \
  -u "${USER}:${PASS}" \
  "${ENDPOINT}" 2>/dev/null) || http_code="000"

if [ "$http_code" = "200" ] || [ "$http_code" = "401" ] || [ "$http_code" = "301" ]; then
  success "Endpoint acessível (HTTP ${http_code})."
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  error "Endpoint não acessível (HTTP ${http_code})."
  error "Verifique: ${ENDPOINT}"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# ============================================================
# TESTE 3: Cluster Health
# ============================================================
echo -e "${BLUE}--- Teste 3/6: Cluster Health ---${NC}"

health_response=$(curl --fail --silent --show-error \
  -u "${USER}:${PASS}" \
  "${ENDPOINT}/_cluster/health" 2>&1) || {
  error "Falha ao consultar _cluster/health."
  error "Detalhes: ${health_response}"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  health_response=""
}

if [ -n "$health_response" ]; then
  cluster_status=$(echo "$health_response" | jq -r '.status' 2>/dev/null || echo "unknown")
  cluster_name=$(echo "$health_response" | jq -r '.cluster_name' 2>/dev/null || echo "unknown")
  num_nodes=$(echo "$health_response" | jq -r '.number_of_nodes' 2>/dev/null || echo "N/A")

  case "$cluster_status" in
    green)
      success "Cluster health: ${cluster_status} 🟢"
      TESTS_PASSED=$((TESTS_PASSED + 1))
      ;;
    yellow)
      warning "Cluster health: ${cluster_status} 🟡 (normal em cluster de 1 nó)"
      TESTS_PASSED=$((TESTS_PASSED + 1))
      ;;
    red)
      error "Cluster health: ${cluster_status} 🔴"
      TESTS_FAILED=$((TESTS_FAILED + 1))
      ;;
  esac
  echo -e "  Nome: ${cluster_name} | Nós: ${num_nodes}"
fi
echo ""

# ============================================================
# TESTE 4: Versão do OpenSearch
# ============================================================
echo -e "${BLUE}--- Teste 4/6: Versão do OpenSearch ---${NC}"

version_response=$(curl --fail --silent --show-error \
  -u "${USER}:${PASS}" \
  "${ENDPOINT}" 2>&1) || {
  error "Falha ao consultar versão."
  TESTS_FAILED=$((TESTS_FAILED + 1))
  version_response=""
}

if [ -n "$version_response" ]; then
  os_version=$(echo "$version_response" | jq -r '.version.number' 2>/dev/null || echo "unknown")
  distribution=$(echo "$version_response" | jq -r '.version.distribution' 2>/dev/null || echo "unknown")
  success "Versão: ${distribution} ${os_version}"
  TESTS_PASSED=$((TESTS_PASSED + 1))
fi
echo ""

# ============================================================
# TESTE 5: Acesso ao Dashboards (porta 5601)
# ============================================================
echo -e "${BLUE}--- Teste 5/6: OpenSearch Dashboards ---${NC}"

dashboards_url="${ENDPOINT}/_dashboards"
dash_code=$(curl --silent -o /dev/null -w "%{http_code}" \
  -u "${USER}:${PASS}" \
  "${dashboards_url}" 2>/dev/null) || dash_code="000"

if [ "$dash_code" = "200" ] || [ "$dash_code" = "302" ] || [ "$dash_code" = "301" ]; then
  success "Dashboards acessível (HTTP ${dash_code})."
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  warning "Dashboards retornou HTTP ${dash_code}."
  warning "Pode ser necessário túnel SSH para acessar."
  TESTS_WARNED=$((TESTS_WARNED + 1))
fi
echo ""

# ============================================================
# TESTE 6: Permissões IAM (teste de escrita)
# ============================================================
echo -e "${BLUE}--- Teste 6/6: Permissões de Acesso ---${NC}"

test_index="_test-ambiente-$(date +%s)"
create_response=$(curl --silent -o /dev/null -w "%{http_code}" \
  -u "${USER}:${PASS}" \
  -X PUT "${ENDPOINT}/${test_index}" \
  -H "Content-Type: application/json" \
  -d '{"settings":{"number_of_shards":1,"number_of_replicas":0}}' 2>/dev/null) || create_response="000"

if [ "$create_response" = "200" ]; then
  success "Permissão de escrita OK."
  TESTS_PASSED=$((TESTS_PASSED + 1))
  # Limpa índice de teste
  curl --silent -o /dev/null \
    -u "${USER}:${PASS}" \
    -X DELETE "${ENDPOINT}/${test_index}" 2>/dev/null || true
else
  error "Sem permissão de escrita (HTTP ${create_response})."
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# ============================================================
# Resultado Final
# ============================================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Resultado dos Testes                   ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "  ${GREEN}Passou:${NC}  ${TESTS_PASSED}"
echo -e "  ${RED}Falhou:${NC}  ${TESTS_FAILED}"
echo -e "  ${YELLOW}Avisos:${NC}  ${TESTS_WARNED}"
echo ""

if [ "$TESTS_FAILED" -eq 0 ]; then
  echo -e "${GREEN}  ✅ Ambiente pronto para os labs!${NC}"
  echo ""
  exit 0
else
  echo -e "${RED}  ❌ Ambiente com problemas. Corrija os erros acima.${NC}"
  echo ""
  exit 1
fi
