#!/bin/bash
set -e

# =============================================================================
# Preparação do Curso — Setup do Aluno
# Configura o ambiente do aluno na EC2 bastion
# Instala dependências, clona repositório e configura variáveis de ambiente
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

# Valores padrão
ENDPOINT=""
USER="admin"
PASS=""
REPO_URL="https://github.com/DevWizardsOps/Curso-opensearch.git"
REGION="${AWS_REGION:-us-east-1}"

# Parse de argumentos
while [[ $# -gt 0 ]]; do
  case $1 in
    --endpoint) ENDPOINT="$2"; shift 2 ;;
    --user)     USER="$2"; shift 2 ;;
    --pass)     PASS="$2"; shift 2 ;;
    --region)   REGION="$2"; shift 2 ;;
    --help|-h)
      echo "Uso: $0 --endpoint URL --user USER --pass PASS [--region REGION]"
      echo ""
      echo "Opções:"
      echo "  --endpoint URL   Endpoint do OpenSearch (obrigatório)"
      echo "  --user USER      Usuário master (padrão: admin)"
      echo "  --pass PASS      Senha master (obrigatório)"
      echo "  --region REGION  Região AWS (padrão: us-east-1)"
      exit 0
      ;;
    *) error "Argumento desconhecido: $1"; exit 1 ;;
  esac
done

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Setup do Aluno                         ${NC}"
echo -e "${BLUE}  Curso AWS OpenSearch — Módulo 6        ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Valida parâmetros obrigatórios
if [ -z "$ENDPOINT" ]; then
  error "Endpoint do OpenSearch é obrigatório."
  echo "  Uso: $0 --endpoint https://seu-dominio.us-east-1.es.amazonaws.com --pass SuaSenha"
  exit 1
fi

if [ -z "$PASS" ]; then
  error "Senha do OpenSearch é obrigatória."
  echo "  Uso: $0 --endpoint ${ENDPOINT} --pass SuaSenha"
  exit 1
fi

# ============================================================
# PASSO 1: Instalar dependências
# ============================================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  PASSO 1/4 — Instalar Dependências      ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# curl
if command -v curl &> /dev/null; then
  success "curl já instalado: $(curl --version | head -1)"
else
  log "Instalando curl..."
  sudo yum install -y curl > /dev/null 2>&1 || sudo apt-get install -y curl > /dev/null 2>&1
  success "curl instalado."
fi

# jq
if command -v jq &> /dev/null; then
  success "jq já instalado: $(jq --version)"
else
  log "Instalando jq..."
  sudo yum install -y jq > /dev/null 2>&1 || sudo apt-get install -y jq > /dev/null 2>&1
  success "jq instalado."
fi

# git
if command -v git &> /dev/null; then
  success "git já instalado: $(git --version)"
else
  log "Instalando git..."
  sudo yum install -y git > /dev/null 2>&1 || sudo apt-get install -y git > /dev/null 2>&1
  success "git instalado."
fi

# aws-cli v2
if command -v aws &> /dev/null; then
  success "aws-cli já instalado: $(aws --version 2>&1 | head -1)"
else
  log "Instalando aws-cli v2..."
  curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
  unzip -q /tmp/awscliv2.zip -d /tmp/
  sudo /tmp/aws/install > /dev/null 2>&1
  rm -rf /tmp/aws /tmp/awscliv2.zip
  success "aws-cli v2 instalado: $(aws --version 2>&1 | head -1)"
fi
echo ""

# ============================================================
# PASSO 2: Clonar repositório
# ============================================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  PASSO 2/4 — Clonar Repositório         ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

REPO_DIR="$HOME/Curso-opensearch"

if [ -d "$REPO_DIR" ]; then
  warning "Repositório já existe em ${REPO_DIR}."
  log "Atualizando..."
  cd "$REPO_DIR"
  git pull --quiet 2>/dev/null || warning "Não foi possível atualizar. Usando versão existente."
  cd - > /dev/null
else
  log "Clonando repositório..."
  git clone --quiet "${REPO_URL}" "${REPO_DIR}" 2>/dev/null || {
    error "Falha ao clonar repositório: ${REPO_URL}"
    warning "Você pode clonar manualmente depois: git clone ${REPO_URL}"
  }
fi

if [ -d "$REPO_DIR" ]; then
  success "Repositório disponível em: ${REPO_DIR}"
  # Torna scripts executáveis
  find "${REPO_DIR}" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
  success "Scripts marcados como executáveis."
fi
echo ""

# ============================================================
# PASSO 3: Configurar variáveis de ambiente
# ============================================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  PASSO 3/4 — Configurar Variáveis       ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

BASHRC="$HOME/.bashrc"

# Remove configurações anteriores do curso
sed -i '/# Curso OpenSearch - Módulo 6/d' "$BASHRC" 2>/dev/null || true
sed -i '/export OPENSEARCH_ENDPOINT=/d' "$BASHRC" 2>/dev/null || true
sed -i '/export OPENSEARCH_USER=/d' "$BASHRC" 2>/dev/null || true
sed -i '/export OPENSEARCH_PASS=/d' "$BASHRC" 2>/dev/null || true
sed -i '/export AWS_REGION=.*# curso-opensearch/d' "$BASHRC" 2>/dev/null || true

# Adiciona novas configurações
{
  echo ""
  echo "# Curso OpenSearch - Módulo 6"
  echo "export OPENSEARCH_ENDPOINT=\"${ENDPOINT}\""
  echo "export OPENSEARCH_USER=\"${USER}\""
  echo "export OPENSEARCH_PASS=\"${PASS}\""
  echo "export AWS_REGION=\"${REGION}\" # curso-opensearch"
} >> "$BASHRC"

# Exporta para a sessão atual
export OPENSEARCH_ENDPOINT="${ENDPOINT}"
export OPENSEARCH_USER="${USER}"
export OPENSEARCH_PASS="${PASS}"
export AWS_REGION="${REGION}"

success "Variáveis configuradas em ${BASHRC}:"
echo -e "  OPENSEARCH_ENDPOINT = ${ENDPOINT}"
echo -e "  OPENSEARCH_USER     = ${USER}"
echo -e "  OPENSEARCH_PASS     = ********"
echo -e "  AWS_REGION          = ${REGION}"
echo ""

# ============================================================
# PASSO 4: Testar conectividade
# ============================================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  PASSO 4/4 — Testar Conectividade       ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

log "Testando conexão com o OpenSearch..."
response=$(curl --fail --silent --show-error \
  -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  "${OPENSEARCH_ENDPOINT}/_cluster/health" 2>&1) || {
  warning "Não foi possível conectar ao OpenSearch."
  warning "Detalhes: ${response}"
  warning "Verifique o endpoint e as credenciais."
  echo ""
  echo -e "  ${YELLOW}O setup foi concluído, mas a conectividade falhou.${NC}"
  echo -e "  ${YELLOW}Verifique se o domínio OpenSearch está ativo e acessível.${NC}"
  echo ""
  exit 0
}

cluster_status=$(echo "$response" | jq -r '.status' 2>/dev/null || echo "unknown")
cluster_name=$(echo "$response" | jq -r '.cluster_name' 2>/dev/null || echo "unknown")

case "$cluster_status" in
  green)  echo -e "  Cluster: ${GREEN}${cluster_status}${NC} 🟢" ;;
  yellow) echo -e "  Cluster: ${YELLOW}${cluster_status}${NC} 🟡" ;;
  red)    echo -e "  Cluster: ${RED}${cluster_status}${NC} 🔴" ;;
esac
echo -e "  Nome: ${cluster_name}"
echo ""

# ============================================================
# Resumo Final
# ============================================================
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✅ Setup Concluído!                     ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "  ${BLUE}Repositório:${NC}  ${REPO_DIR}"
echo -e "  ${BLUE}Endpoint:${NC}     ${ENDPOINT}"
echo -e "  ${BLUE}Região:${NC}       ${REGION}"
echo -e "  ${BLUE}Cluster:${NC}      ${cluster_status}"
echo ""
echo -e "  ${YELLOW}Para começar os labs:${NC}"
echo -e "    cd ${REPO_DIR}/modulo6-lab/lab1-bulk"
echo -e "    ./setup.sh"
echo -e "    ./ingestao-individual.sh"
echo -e "    ./ingestao-bulk.sh"
echo ""
echo -e "  ${YELLOW}Recarregue o shell para aplicar as variáveis:${NC}"
echo -e "    source ~/.bashrc"
echo ""
