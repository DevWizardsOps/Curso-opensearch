#!/bin/bash
set -e

# =============================================================================
# Lab 2 — Filter vs Query Context: Query Context
# Executa busca com match no campo descricao (calcula _score de relevância)
# =============================================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INDEX_NAME="lab2-produtos"
RESULT_FILE="/tmp/lab2-query-result.txt"

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
echo -e "${BLUE}  Lab 2 — Query Context                  ${NC}"
echo -e "${BLUE}  (match + cálculo de _score)             ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

check_env
check_connectivity

log "Executando busca com match no campo 'descricao' (query context)..."
log "Query: { \"match\": { \"descricao\": \"produto\" } }"
echo ""

# Executa a busca com match — query context calcula _score para cada documento
response=$(curl --fail --silent --show-error \
  -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X GET "${OPENSEARCH_ENDPOINT}/${INDEX_NAME}/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "size": 3,
    "query": {
      "match": {
        "descricao": "produto"
      }
    }
  }' 2>&1) || {
  error "Falha na busca. Verifique se o índice '${INDEX_NAME}' existe."
  error "Execute ./setup.sh primeiro."
  error "Detalhes: ${response}"
  exit 1
}

# Extrai métricas do response
took=$(echo "$response" | jq '.took' 2>/dev/null || echo "N/A")
total=$(echo "$response" | jq '.hits.total.value' 2>/dev/null || echo "N/A")

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Resultado — Query Context              ${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "  Tempo de resposta : ${YELLOW}${took} ms${NC}"
echo -e "  Total de hits     : ${GREEN}${total}${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Exibe os primeiros 3 resultados com _score
echo -e "${BLUE}📋 Primeiros 3 resultados (com _score de relevância):${NC}"
echo ""
echo "$response" | jq -r '
  .hits.hits[] |
  "  _score: \(._score)\n  id: \(._source.id)\n  nome: \(._source.nome)\n  descricao: \(._source.descricao[:60])...\n  ---"
' 2>/dev/null || warning "Não foi possível formatar os resultados com jq."
echo ""

# Salva resultado para comparação posterior com filter-context.sh
echo "QUERY_TOOK=${took}" > "$RESULT_FILE"
echo "QUERY_TOTAL=${total}" >> "$RESULT_FILE"
success "Resultado salvo em ${RESULT_FILE} para comparação com filter context."
echo ""

echo -e "${YELLOW}💡 Observação:${NC}"
echo -e "   Query context calcula ${YELLOW}_score${NC} para cada documento."
echo -e "   Isso permite ranquear resultados por relevância, mas tem custo computacional."
echo -e "   Execute ${BLUE}./filter-context.sh${NC} para comparar com filter context."
echo ""
