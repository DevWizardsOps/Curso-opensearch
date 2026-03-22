#!/bin/bash
set -e

# =============================================================================
# Lab 0 — Criação do Ambiente OpenSearch: Configurar Variáveis de Ambiente
# Configura OPENSEARCH_ENDPOINT, OPENSEARCH_USER e OPENSEARCH_PASS no ~/.bashrc
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

# =============================================================================
# Parse de parâmetros
# =============================================================================

ENDPOINT=""
USER=""
PASS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --endpoint)
      ENDPOINT="$2"
      shift 2
      ;;
    --user)
      USER="$2"
      shift 2
      ;;
    --pass)
      PASS="$2"
      shift 2
      ;;
    --help|-h)
      echo "Uso: ./configurar-ambiente.sh [--endpoint URL] [--user USER] [--pass PASS]"
      echo ""
      echo "Configura as variáveis de ambiente do OpenSearch no ~/.bashrc."
      echo ""
      echo "Opções:"
      echo "  --endpoint URL   Endpoint do domínio OpenSearch (https://...)"
      echo "  --user USER      Usuário master do OpenSearch"
      echo "  --pass PASS      Senha master do OpenSearch"
      echo ""
      echo "Se os parâmetros não forem fornecidos, serão solicitados interativamente."
      exit 0
      ;;
    *)
      error "Parâmetro desconhecido: $1"
      echo "Use --help para ver as opções disponíveis."
      exit 1
      ;;
  esac
done

# =============================================================================
# Coleta interativa (se parâmetros não fornecidos)
# =============================================================================

collect_parameters() {
  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}  Configuração do Ambiente OpenSearch    ${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""

  # Endpoint
  if [ -z "$ENDPOINT" ]; then
    log "Informe o endpoint do seu domínio OpenSearch."
    log "Exemplo: https://search-meu-dominio-abc123.us-east-1.es.amazonaws.com"
    echo ""
    read -r -p "$(echo -e "${BLUE}[INFO]${NC} Endpoint: ")" ENDPOINT
  fi

  # Validação do endpoint
  if [ -z "$ENDPOINT" ]; then
    error "O endpoint não pode ser vazio."
    exit 1
  fi

  if [[ ! "$ENDPOINT" =~ ^https:// ]]; then
    error "O endpoint deve começar com https://"
    echo -e "  Exemplo: ${YELLOW}https://search-meu-dominio-abc123.us-east-1.es.amazonaws.com${NC}"
    exit 1
  fi

  # Remove barra final se presente
  ENDPOINT="${ENDPOINT%/}"

  # Usuário master
  if [ -z "$USER" ]; then
    echo ""
    read -r -p "$(echo -e "${BLUE}[INFO]${NC} Usuário master [admin]: ")" USER
    USER="${USER:-admin}"
  fi

  if [ -z "$USER" ]; then
    error "O usuário não pode ser vazio."
    exit 1
  fi

  # Senha master
  if [ -z "$PASS" ]; then
    echo ""
    read -r -s -p "$(echo -e "${BLUE}[INFO]${NC} Senha master: ")" PASS
    echo ""
  fi

  if [ -z "$PASS" ]; then
    error "A senha não pode ser vazia."
    exit 1
  fi
}

# =============================================================================
# Configuração do ~/.bashrc
# =============================================================================

configure_bashrc() {
  local bashrc_file="$HOME/.bashrc"

  log "Configurando variáveis de ambiente no ${bashrc_file}..."

  # Remove variáveis antigas para evitar duplicatas
  if [ -f "$bashrc_file" ]; then
    sed -i '/^export OPENSEARCH_ENDPOINT=/d' "$bashrc_file"
    sed -i '/^export OPENSEARCH_USER=/d' "$bashrc_file"
    sed -i '/^export OPENSEARCH_PASS=/d' "$bashrc_file"
  fi

  # Adiciona as novas variáveis
  echo "export OPENSEARCH_ENDPOINT=\"${ENDPOINT}\"" >> "$bashrc_file"
  echo "export OPENSEARCH_USER=\"${USER}\"" >> "$bashrc_file"
  echo "export OPENSEARCH_PASS=\"${PASS}\"" >> "$bashrc_file"

  success "Variáveis adicionadas ao ${bashrc_file}"
}

# =============================================================================
# Ativação das variáveis na sessão atual
# =============================================================================

activate_variables() {
  log "Ativando variáveis na sessão atual..."

  export OPENSEARCH_ENDPOINT="${ENDPOINT}"
  export OPENSEARCH_USER="${USER}"
  export OPENSEARCH_PASS="${PASS}"

  success "Variáveis exportadas na sessão atual."
}

# =============================================================================
# Resumo
# =============================================================================

show_summary() {
  echo ""
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}  Ambiente Configurado com Sucesso!      ${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo ""
  echo -e "  OPENSEARCH_ENDPOINT: ${GREEN}${ENDPOINT}${NC}"
  echo -e "  OPENSEARCH_USER:     ${GREEN}${USER}${NC}"
  echo -e "  OPENSEARCH_PASS:     ${GREEN}********${NC}"
  echo ""
  echo -e "As variáveis foram salvas no ${BLUE}~/.bashrc${NC} e estão"
  echo -e "disponíveis na sessão atual."
  echo ""
  echo -e "Próximo passo:"
  echo -e "  ${BLUE}./testar-conexao.sh${NC}"
  echo ""
}

# =============================================================================
# Execução principal
# =============================================================================

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Lab 0 — Configurar Ambiente OpenSearch ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Este script configura as variáveis de ambiente"
echo "necessárias para todos os labs do curso."
echo ""

# Passo 1: Coletar parâmetros
collect_parameters

# Passo 2: Exibir resumo antes de aplicar
echo ""
echo -e "${BLUE}--- Resumo da Configuração ---${NC}"
echo -e "  Endpoint: ${GREEN}${ENDPOINT}${NC}"
echo -e "  Usuário:  ${GREEN}${USER}${NC}"
echo -e "  Senha:    ${GREEN}********${NC}"
echo ""

# Passo 3: Configurar ~/.bashrc
configure_bashrc

# Passo 4: Ativar variáveis na sessão atual
activate_variables

# Passo 5: Exibir resumo final
show_summary

success "Script finalizado."
echo ""
