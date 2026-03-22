#!/bin/bash
set -e

# =============================================================================
# Lab 4 — Oversharding: Criar Índices com Shards Diferentes
# Cria 3 índices com 1, 5 e 20 shards e indexa o mesmo dataset em cada um
# =============================================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATASET_PATH="${SCRIPT_DIR}/../dataset/dataset.json"

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

# Cria um índice com número específico de shards
create_index_with_shards() {
  local index_name="$1"
  local num_shards="$2"

  # Verifica se já existe
  local http_code
  http_code=$(curl --silent -o /dev/null -w "%{http_code}" \
    -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
    "${OPENSEARCH_ENDPOINT}/${index_name}" 2>/dev/null) || true

  if [ "$http_code" = "200" ]; then
    warning "Índice '${index_name}' já existe. Deletando para recriar..."
    curl --fail --silent --show-error -o /dev/null \
      -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
      -X DELETE "${OPENSEARCH_ENDPOINT}/${index_name}" 2>/dev/null || true
  fi

  log "Criando índice '${index_name}' com ${num_shards} shard(s)..."
  local response
  response=$(curl --fail --silent --show-error \
    -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
    -X PUT "${OPENSEARCH_ENDPOINT}/${index_name}" \
    -H "Content-Type: application/json" \
    -d "{
      \"settings\": {
        \"number_of_shards\": ${num_shards},
        \"number_of_replicas\": 0
      },
      \"mappings\": {
        \"properties\": {
          \"id\":        { \"type\": \"keyword\" },
          \"nome\":      { \"type\": \"text\", \"fields\": { \"keyword\": { \"type\": \"keyword\" } } },
          \"status\":    { \"type\": \"keyword\" },
          \"descricao\": { \"type\": \"text\" },
          \"usuario\":   { \"type\": \"keyword\" },
          \"timestamp\": { \"type\": \"date\", \"format\": \"strict_date_time\" }
        }
      }
    }" 2>&1) || {
    local err_type
    err_type=$(echo "$response" | jq -r '.error.type' 2>/dev/null || echo "unknown")
    if echo "$response" | grep -qi "invalid_index_name_exception\|too_many_shards\|max_shards_per_node"; then
      warning "Cluster não suporta ${num_shards} shards para '${index_name}'."
      warning "Causa: ${err_type}"
      warning "Sugestão: reduza o número de shards ou aumente 'cluster.max_shards_per_node'."
      warning "Exemplo: PUT /_cluster/settings com {\"persistent\":{\"cluster.max_shards_per_node\":\"100\"}}"
      return 1
    fi
    error "Falha ao criar índice '${index_name}': ${response}"
    exit 1
  }

  success "Índice '${index_name}' criado com ${num_shards} shard(s)."
  return 0
}

# Indexa o dataset em um índice via _bulk
index_dataset() {
  local index_name="$1"

  if [ ! -f "$DATASET_PATH" ]; then
    error "Dataset não encontrado em ${DATASET_PATH}"
    exit 1
  fi

  local total
  total=$(awk 'NR%2==0' "$DATASET_PATH" | wc -l | tr -d ' ')
  log "Indexando ${total} documentos em '${index_name}' via bulk API..."

  # Substitui o _index pelo nome correto
  local bulk_data
  bulk_data=$(sed 's/"_index"[[:space:]]*:[[:space:]]*"[^"]*"/"_index": "'"${index_name}"'"/g' "$DATASET_PATH")

  local response
  response=$(echo "$bulk_data" | curl --fail --silent --show-error \
    -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
    -X POST "${OPENSEARCH_ENDPOINT}/_bulk" \
    -H "Content-Type: application/json" \
    --data-binary @- 2>&1) || {
    error "Falha na ingestão bulk em '${index_name}'"
    error "Detalhes: ${response}"
    exit 1
  }

  local errors
  errors=$(echo "$response" | jq '.errors' 2>/dev/null || echo "false")
  if [ "$errors" = "true" ]; then
    local failed
    failed=$(echo "$response" | jq '[.items[] | select(.index.error != null)] | length' 2>/dev/null || echo "?")
    warning "Alguns documentos tiveram erros em '${index_name}': ${failed} falhas"
  else
    success "${total} documentos indexados em '${index_name}'."
  fi
}

# =============================================================================
# Execução principal
# =============================================================================

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Lab 4 — Oversharding                   ${NC}"
echo -e "${BLUE}  Criar Índices com Shards Diferentes     ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

check_env
check_connectivity

echo ""
log "Criando 3 índices com configurações distintas de shards..."
echo ""

# Índice com 1 shard
if create_index_with_shards "lab4-shard1" 1; then
  index_dataset "lab4-shard1"
fi
echo ""

# Índice com 5 shards
if create_index_with_shards "lab4-shard5" 5; then
  index_dataset "lab4-shard5"
fi
echo ""

# Índice com 20 shards
if create_index_with_shards "lab4-shard20" 20; then
  index_dataset "lab4-shard20"
else
  warning "Índice lab4-shard20 não foi criado."
  warning "O lab pode continuar com lab4-shard1 e lab4-shard5."
fi
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Resumo dos índices criados:             ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

for idx in lab4-shard1 lab4-shard5 lab4-shard20; do
  count=$(curl --silent \
    -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
    "${OPENSEARCH_ENDPOINT}/${idx}/_count" 2>/dev/null | jq '.count' 2>/dev/null || echo "N/A")
  shards=$(curl --silent \
    -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
    "${OPENSEARCH_ENDPOINT}/${idx}/_settings" 2>/dev/null | \
    jq -r ".[\"${idx}\"].settings.index.number_of_shards" 2>/dev/null || echo "N/A")
  printf "  %-20s shards: %-4s docs: %s\n" "${idx}" "${shards}" "${count}"
done

echo ""
success "Índices criados. Execute ./comparar-performance.sh para comparar a performance."
echo ""
