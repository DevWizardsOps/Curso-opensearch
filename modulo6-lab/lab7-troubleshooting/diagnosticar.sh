#!/bin/bash
set -e

# =============================================================================
# Lab 7 — Troubleshooting Controlado: Diagnosticar
# Guia o aluno passo a passo no diagnóstico do problema:
#   Passo 1: GET /lab7-problema/_mapping — identifica timestamp como keyword
#   Passo 2: Range query que retorna 0 resultados — demonstra o problema
#   Passo 3: GET /_cluster/health — verifica saúde geral
#   Exibe diagnóstico final com causa raiz
# =============================================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INDEX_PROBLEMA="lab7-problema"

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
echo -e "${BLUE}  Diagnóstico do Problema                 ${NC}"
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

echo ""
echo -e "${YELLOW}Iniciando diagnóstico passo a passo...${NC}"
echo ""

# ============================================================
# PASSO 1: Verificar o mapping do índice
# ============================================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  PASSO 1/3 — Verificar Mapping          ${NC}"
echo -e "${BLUE}  GET /${INDEX_PROBLEMA}/_mapping         ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

log "Consultando mapping do índice '${INDEX_PROBLEMA}'..."
echo ""

mapping_response=$(curl --fail --silent --show-error \
  -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  "${OPENSEARCH_ENDPOINT}/${INDEX_PROBLEMA}/_mapping" 2>&1) || {
  error "Falha ao consultar mapping"
  error "Detalhes: ${mapping_response}"
  exit 1
}

echo "$mapping_response" | jq '.' 2>/dev/null || echo "$mapping_response"
echo ""

# Extrai tipo do campo timestamp
timestamp_type=$(echo "$mapping_response" | \
  jq -r ".[\"${INDEX_PROBLEMA}\"].mappings.properties.timestamp.type" 2>/dev/null || echo "unknown")

echo -e "${YELLOW}  Análise do mapping:${NC}"
echo ""
if [ "$timestamp_type" = "keyword" ]; then
  echo -e "  Campo 'timestamp' : ${RED}${timestamp_type}${NC} ← ${RED}PROBLEMA IDENTIFICADO!${NC}"
  echo -e "  ${RED}O campo timestamp está mapeado como 'keyword' em vez de 'date'.${NC}"
  echo -e "  ${RED}Isso impede que range queries de data funcionem corretamente.${NC}"
elif [ "$timestamp_type" = "date" ]; then
  echo -e "  Campo 'timestamp' : ${GREEN}${timestamp_type}${NC} ← mapping correto"
  warning "O mapping parece correto. O problema pode ter sido corrigido."
else
  echo -e "  Campo 'timestamp' : ${YELLOW}${timestamp_type}${NC}"
fi
echo ""

# ============================================================
# PASSO 2: Executar range query que demonstra o problema
# ============================================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  PASSO 2/3 — date_histogram Aggregation ${NC}"
echo -e "${BLUE}  GET /${INDEX_PROBLEMA}/_search          ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

log "Executando date_histogram aggregation em 'timestamp'..."
log "Essa aggregation só funciona com campos do tipo 'date'."
echo ""

agg_response=$(curl --silent --show-error \
  -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X GET "${OPENSEARCH_ENDPOINT}/${INDEX_PROBLEMA}/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "size": 0,
    "aggs": {
      "docs_por_mes": {
        "date_histogram": {
          "field": "timestamp",
          "calendar_interval": "month"
        }
      }
    }
  }' 2>&1)

agg_error=$(echo "$agg_response" | jq -r '.error.type // empty' 2>/dev/null || echo "")
agg_status=$(echo "$agg_response" | jq -r '.status // empty' 2>/dev/null || echo "")

if [ -n "$agg_error" ] || [ "$agg_status" = "400" ] || [ "$agg_status" = "500" ]; then
  range_hits="ERRO"
  echo -e "  ${RED}❌ date_histogram FALHOU no campo 'timestamp'${NC}"
  echo ""
  echo -e "  ${YELLOW}Erro:${NC}"
  echo "  $(echo "$agg_response" | jq -r '.error.reason // .error.root_cause[0].reason // "Erro desconhecido"' 2>/dev/null | head -2)"
  echo ""
  echo -e "  ${RED}O OpenSearch não consegue executar date_histogram em campos 'keyword'.${NC}"
  echo -e "  ${RED}Isso confirma que o campo 'timestamp' está com o tipo errado.${NC}"
else
  range_hits="OK (inesperado)"
  echo -e "  ${YELLOW}⚠️  date_histogram não retornou erro (comportamento pode variar por versão)${NC}"
fi
echo ""

# ============================================================
# PASSO 3: Verificar saúde geral do cluster
# ============================================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  PASSO 3/3 — Saúde do Cluster           ${NC}"
echo -e "${BLUE}  GET /_cluster/health                   ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

log "Consultando saúde do cluster..."
echo ""

health_response=$(curl --fail --silent --show-error \
  -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  "${OPENSEARCH_ENDPOINT}/_cluster/health?pretty" 2>&1) || {
  error "Falha ao consultar cluster health"
  error "Detalhes: ${health_response}"
  exit 1
}

cluster_status=$(echo "$health_response" | jq -r '.status' 2>/dev/null || echo "unknown")
unassigned=$(echo "$health_response" | jq -r '.unassigned_shards' 2>/dev/null || echo "N/A")

case "$cluster_status" in
  green)  echo -e "  Status do cluster : ${GREEN}${cluster_status}${NC} 🟢" ;;
  yellow) echo -e "  Status do cluster : ${YELLOW}${cluster_status}${NC} 🟡" ;;
  red)    echo -e "  Status do cluster : ${RED}${cluster_status}${NC} 🔴" ;;
  *)      echo -e "  Status do cluster : ${cluster_status}" ;;
esac
echo -e "  Shards não alocados: ${unassigned}"
echo ""

if [ "$cluster_status" = "green" ] || [ "$cluster_status" = "yellow" ]; then
  success "Cluster saudável — o problema é de mapping, não de infraestrutura."
fi
echo ""

# ============================================================
# Diagnóstico Final
# ============================================================
echo -e "${RED}========================================${NC}"
echo -e "${RED}  DIAGNÓSTICO FINAL                      ${NC}"
echo -e "${RED}========================================${NC}"
echo ""
echo -e "  ${RED}Causa raiz: campo 'timestamp' mapeado como 'keyword' em vez de 'date'${NC}"
echo ""
echo -e "  Evidências coletadas:"
echo -e "    1. ${YELLOW}Mapping${NC}: timestamp.type = '${timestamp_type}' (deveria ser 'date')"
echo -e "    2. ${YELLOW}date_histogram${NC}: ${range_hits} (falha confirma tipo incorreto)"
echo -e "    3. ${YELLOW}Cluster health${NC}: ${cluster_status} (problema é de mapping, não de infra)"
echo ""
echo -e "  ${GREEN}Solução:${NC}"
echo -e "    1. Criar novo índice 'lab7-corrigido' com timestamp mapeado como 'date'"
echo -e "    2. Reindexar dados via POST /_reindex"
echo -e "    3. Validar que range query funciona no novo índice"
echo ""
echo -e "  Execute ${GREEN}./corrigir.sh${NC} para aplicar a correção."
echo ""
