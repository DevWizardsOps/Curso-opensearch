#!/bin/bash
set -e

# =============================================================================
# Lab 7 — Troubleshooting Controlado: Corrigir
# Cria lab7-corrigido com mapping CORRETO (timestamp como date)
# Reindexia via POST /_reindex
# Valida que range query funciona no novo índice
# Consulta _cluster/health e exibe status final
# =============================================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INDEX_PROBLEMA="lab7-problema"
INDEX_CORRIGIDO="lab7-corrigido"

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
echo -e "${BLUE}  Lab 7 — Troubleshooting Controlado     ${NC}"
echo -e "${BLUE}  Corrigir o Problema                    ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

check_env
check_connectivity

# Verifica se o índice de problema existe
http_code=$(curl --silent -o /dev/null -w "%{http_code}" \
  -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  "${OPENSEARCH_ENDPOINT}/${INDEX_PROBLEMA}" 2>/dev/null) || true

if [ "$http_code" != "200" ]; then
  error "Índice '${INDEX_PROBLEMA}' não encontrado."
  error "Execute ./criar-problema.sh primeiro para criar o cenário de problema."
  exit 1
fi

# Remove índice corrigido se já existir
existing=$(curl --silent -o /dev/null -w "%{http_code}" \
  -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  "${OPENSEARCH_ENDPOINT}/${INDEX_CORRIGIDO}" 2>/dev/null) || true

if [ "$existing" = "200" ]; then
  log "Removendo índice '${INDEX_CORRIGIDO}' anterior..."
  curl --fail --silent --show-error -o /dev/null \
    -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
    -X DELETE "${OPENSEARCH_ENDPOINT}/${INDEX_CORRIGIDO}" 2>/dev/null || true
  success "Índice anterior removido."
  echo ""
fi

# ============================================================
# PASSO 1: Criar índice com mapping CORRETO
# ============================================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  PASSO 1/4 — Criar Índice Corrigido     ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

log "Criando índice '${INDEX_CORRIGIDO}' com mapping CORRETO (timestamp como date)..."

response=$(curl --fail --silent --show-error \
  -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X PUT "${OPENSEARCH_ENDPOINT}/${INDEX_CORRIGIDO}" \
  -H "Content-Type: application/json" \
  -d '{
    "settings": {
      "number_of_shards": 1,
      "number_of_replicas": 0
    },
    "mappings": {
      "properties": {
        "id":        { "type": "keyword" },
        "nome":      { "type": "text" },
        "status":    { "type": "keyword" },
        "descricao": { "type": "text" },
        "usuario":   { "type": "keyword" },
        "timestamp": { "type": "date", "format": "strict_date_time||strict_date_optional_time||epoch_millis" }
      }
    }
  }' 2>&1) || {
  error "Falha ao criar índice '${INDEX_CORRIGIDO}'"
  error "Detalhes: ${response}"
  exit 1
}

success "Índice '${INDEX_CORRIGIDO}' criado com timestamp mapeado como 'date'."
echo ""

# ============================================================
# PASSO 2: Reindexar dados via _reindex
# ============================================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  PASSO 2/4 — Reindexar Dados            ${NC}"
echo -e "${BLUE}  POST /_reindex                         ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

log "Reindexando dados de '${INDEX_PROBLEMA}' para '${INDEX_CORRIGIDO}'..."
log "POST /_reindex: { source: { index: '${INDEX_PROBLEMA}' }, dest: { index: '${INDEX_CORRIGIDO}' } }"
echo ""

reindex_response=$(curl --fail --silent --show-error \
  -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X POST "${OPENSEARCH_ENDPOINT}/_reindex" \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": {
      \"index\": \"${INDEX_PROBLEMA}\"
    },
    \"dest\": {
      \"index\": \"${INDEX_CORRIGIDO}\"
    }
  }" 2>&1) || {
  error "Falha no _reindex"
  error "Detalhes: ${reindex_response}"
  exit 1
}

reindex_total=$(echo "$reindex_response" | jq '.total' 2>/dev/null || echo "N/A")
reindex_created=$(echo "$reindex_response" | jq '.created' 2>/dev/null || echo "N/A")
reindex_failures=$(echo "$reindex_response" | jq '.failures | length' 2>/dev/null || echo "0")

echo -e "  Documentos processados : ${reindex_total}"
echo -e "  Documentos criados     : ${reindex_created}"
echo -e "  Falhas                 : ${reindex_failures}"
echo ""

if [ "$reindex_failures" != "0" ] && [ "$reindex_failures" != "null" ]; then
  warning "Houve ${reindex_failures} falha(s) durante o reindex."
  warning "Detalhes: $(echo "$reindex_response" | jq '.failures' 2>/dev/null)"
else
  success "Reindex concluído sem falhas. ${reindex_created} documentos migrados."
fi
echo ""

# Aguarda indexação
sleep 1

# ============================================================
# PASSO 3: Validar que range query funciona no novo índice
# ============================================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  PASSO 3/4 — Validar Correção           ${NC}"
echo -e "${BLUE}  Range query em '${INDEX_CORRIGIDO}'    ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

log "Executando range query em 'timestamp' no índice corrigido..."
log "Query: { range: { timestamp: { gte: '2024-01-01', lte: '2024-12-31' } } }"
echo ""

validate_response=$(curl --fail --silent --show-error \
  -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X GET "${OPENSEARCH_ENDPOINT}/${INDEX_CORRIGIDO}/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "range": {
        "timestamp": {
          "gte": "2024-01-01",
          "lte": "2024-12-31"
        }
      }
    },
    "size": 3,
    "_source": ["id", "nome", "timestamp"]
  }' 2>&1) || {
  error "Falha na range query de validação"
  error "Detalhes: ${validate_response}"
  exit 1
}

validate_hits=$(echo "$validate_response" | jq '.hits.total.value' 2>/dev/null || echo "N/A")
validate_took=$(echo "$validate_response" | jq '.took' 2>/dev/null || echo "N/A")

echo -e "  took (ms)   : ${validate_took}"
echo -e "  Total hits  : ${GREEN}${validate_hits}${NC}"
echo ""

if [ "$validate_hits" != "0" ] && [ "$validate_hits" != "null" ] && [ "$validate_hits" != "N/A" ]; then
  success "Range query retornou ${validate_hits} resultados no índice corrigido!"
  echo ""
  echo -e "${BLUE}  Primeiros documentos encontrados:${NC}"
  echo "$validate_response" | jq -r '.hits.hits[]._source | "  id: \(.id) | nome: \(.nome) | timestamp: \(.timestamp)"' 2>/dev/null || true
  echo ""
else
  warning "Range query ainda retornou 0 resultados."
  warning "Verifique se os timestamps nos documentos estão no formato ISO 8601 correto."
fi

# ============================================================
# PASSO 4: Verificar saúde do cluster
# ============================================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  PASSO 4/4 — Saúde do Cluster           ${NC}"
echo -e "${BLUE}  GET /_cluster/health                   ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

log "Consultando saúde do cluster após a correção..."
echo ""

health_response=$(curl --fail --silent --show-error \
  -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  "${OPENSEARCH_ENDPOINT}/_cluster/health?pretty" 2>&1) || {
  error "Falha ao consultar cluster health"
  error "Detalhes: ${health_response}"
  exit 1
}

cluster_status=$(echo "$health_response" | jq -r '.status' 2>/dev/null || echo "unknown")
active_shards=$(echo "$health_response" | jq -r '.active_shards' 2>/dev/null || echo "N/A")
unassigned=$(echo "$health_response" | jq -r '.unassigned_shards' 2>/dev/null || echo "N/A")

case "$cluster_status" in
  green)
    echo -e "  Status do cluster : ${GREEN}${cluster_status}${NC} 🟢"
    ;;
  yellow)
    echo -e "  Status do cluster : ${YELLOW}${cluster_status}${NC} 🟡"
    echo -e "  ${YELLOW}(Normal em cluster de 1 nó — réplicas não podem ser alocadas no mesmo nó)${NC}"
    ;;
  red)
    echo -e "  Status do cluster : ${RED}${cluster_status}${NC} 🔴"
    error "Cluster em estado RED após a correção. Verifique os shards não alocados."
    ;;
esac

echo -e "  Shards ativos     : ${active_shards}"
echo -e "  Shards não alocados: ${unassigned}"
echo ""

# ============================================================
# Resultado Final
# ============================================================
if [ "$cluster_status" = "green" ] || [ "$cluster_status" = "yellow" ]; then
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}  ✅ CORREÇÃO APLICADA COM SUCESSO!       ${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo ""
  echo -e "  Resumo da correção:"
  echo -e "    • Índice problemático : ${RED}${INDEX_PROBLEMA}${NC} (timestamp=keyword)"
  echo -e "    • Índice corrigido    : ${GREEN}${INDEX_CORRIGIDO}${NC} (timestamp=date)"
  echo -e "    • Documentos migrados : ${reindex_created}"
  echo -e "    • Range query         : ${GREEN}${validate_hits} resultados${NC} (antes: 0)"
  echo -e "    • Cluster health      : ${cluster_status}"
  echo ""
  echo -e "  ${YELLOW}Lição aprendida:${NC}"
  echo -e "    Sempre defina o mapping explicitamente antes de indexar dados."
  echo -e "    O dynamic mapping pode inferir tipos incorretos para campos de data."
  echo -e "    Use 'type: date' com 'format' explícito para campos de timestamp."
  echo ""
else
  error "Cluster em estado ${cluster_status} após a correção."
  exit 1
fi
