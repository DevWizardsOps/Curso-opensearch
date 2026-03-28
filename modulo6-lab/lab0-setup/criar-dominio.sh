#!/bin/bash
set -e

# =============================================================================
# Lab 0 — Criação do Ambiente OpenSearch: Criar Domínio
# Script helper que auxilia o aluno na criação do OpenSearch Domain via AWS CLI
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
# Validação de pré-requisitos
# =============================================================================

check_aws_cli() {
  log "Verificando se o AWS CLI está instalado..."
  if ! command -v aws &> /dev/null; then
    error "AWS CLI não encontrado. Instale com: sudo yum install -y aws-cli"
    exit 1
  fi
  success "AWS CLI encontrado."

  log "Verificando credenciais AWS..."
  if ! aws sts get-caller-identity &> /dev/null; then
    error "Credenciais AWS não configuradas ou inválidas."
    echo -e "  Execute: ${YELLOW}aws configure${NC}"
    echo -e "  Ou peça ao instrutor para verificar suas credenciais IAM."
    exit 1
  fi
  local account_id
  account_id=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null)
  success "Credenciais válidas — Conta AWS: ${account_id}"
}

# =============================================================================
# Coleta de parâmetros do aluno
# =============================================================================

collect_parameters() {
  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}  Configuração do Domínio OpenSearch    ${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""

  # Nome do domínio — usa $ALUNO_ID se disponível para personalizar
  local default_domain="opensearch-aluno"
  if [ -n "${ALUNO_ID:-}" ]; then
    default_domain="opensearch-${ALUNO_ID}"
  fi
  read -r -p "$(echo -e "${BLUE}[INFO]${NC} Nome do domínio [${default_domain}]: ")" DOMAIN_NAME
  DOMAIN_NAME="${DOMAIN_NAME:-${default_domain}}"

  # Usuário master
  read -r -p "$(echo -e "${BLUE}[INFO]${NC} Usuário master [admin]: ")" MASTER_USER
  MASTER_USER="${MASTER_USER:-admin}"

  # Senha master
  while true; do
    read -r -s -p "$(echo -e "${BLUE}[INFO]${NC} Senha master (mín. 8 chars, maiúscula, minúscula, número, especial): ")" MASTER_PASS
    echo ""

    if [ -z "$MASTER_PASS" ]; then
      error "A senha não pode ser vazia."
      continue
    fi

    if [ ${#MASTER_PASS} -lt 8 ]; then
      error "A senha deve ter no mínimo 8 caracteres."
      continue
    fi

    break
  done

  # Região AWS
  AWS_REGION=$(aws configure get region 2>/dev/null || echo "us-east-1")
  log "Região AWS detectada: ${AWS_REGION}"

  echo ""
  echo -e "${BLUE}--- Resumo da Configuração ---${NC}"
  echo -e "  Domínio:       ${GREEN}${DOMAIN_NAME}${NC}"
  echo -e "  Instância:     ${GREEN}t3.small.search${NC}"
  echo -e "  Nós:           ${GREEN}1${NC}"
  echo -e "  EBS:           ${GREEN}10 GB (gp3)${NC}"
  echo -e "  Usuário:       ${GREEN}${MASTER_USER}${NC}"
  echo -e "  Região:        ${GREEN}${AWS_REGION}${NC}"
  echo -e "  HTTPS:         ${GREEN}Obrigatório${NC}"
  echo -e "  Fine-grained:  ${GREEN}Habilitado${NC}"
  echo ""
}

# =============================================================================
# Criação do domínio
# =============================================================================

create_domain() {
  log "Criando domínio OpenSearch '${DOMAIN_NAME}'..."
  echo ""

  local response
  response=$(aws opensearch create-domain \
    --domain-name "${DOMAIN_NAME}" \
    --engine-version "OpenSearch_2.13" \
    --cluster-config '{
      "InstanceType": "t3.small.search",
      "InstanceCount": 1
    }' \
    --ebs-options '{
      "EBSEnabled": true,
      "VolumeType": "gp3",
      "VolumeSize": 10
    }' \
    --node-to-node-encryption-options '{"Enabled": true}' \
    --encryption-at-rest-options '{"Enabled": true}' \
    --domain-endpoint-options '{"EnforceHTTPS": true}' \
    --advanced-security-options "{
      \"Enabled\": true,
      \"InternalUserDatabaseEnabled\": true,
      \"MasterUserOptions\": {
        \"MasterUserName\": \"${MASTER_USER}\",
        \"MasterUserPassword\": \"${MASTER_PASS}\"
      }
    }" 2>&1) || {
    error "Falha ao criar o domínio '${DOMAIN_NAME}'."
    echo -e "${RED}Detalhes:${NC}"
    echo "$response"
    echo ""
    echo -e "${YELLOW}Possíveis causas:${NC}"
    echo "  1. Já existe um domínio com o nome '${DOMAIN_NAME}'"
    echo "  2. Permissões IAM insuficientes (necessário es:* e opensearch:*)"
    echo "  3. Limite de domínios atingido na conta AWS"
    echo "  4. Senha não atende aos requisitos de complexidade"
    exit 1
  }

  success "Comando de criação enviado com sucesso!"
}

# =============================================================================
# Monitoramento do status de criação
# =============================================================================

show_wait_instructions() {
  echo ""
  echo -e "${YELLOW}========================================${NC}"
  echo -e "${YELLOW}  ⏱️  Aguardando criação do domínio      ${NC}"
  echo -e "${YELLOW}========================================${NC}"
  echo ""
  echo -e "${YELLOW}[AVISO]${NC} A criação do domínio leva ${GREEN}15 a 20 minutos${NC}."
  echo ""
  echo "Enquanto aguarda, você pode:"
  echo "  - Revisar o material do curso"
  echo "  - Explorar a documentação do OpenSearch"
  echo "  - Verificar o status no console AWS:"
  echo "    https://console.aws.amazon.com/aos/home"
  echo ""
  echo "Para verificar o status via CLI:"
  echo -e "  ${BLUE}aws opensearch describe-domain --domain-name \"${DOMAIN_NAME}\" --query 'DomainStatus.Processing'${NC}"
  echo ""
  echo "Quando retornar 'false', o domínio está pronto."
  echo ""
}

poll_domain_status() {
  read -r -p "$(echo -e "${BLUE}[INFO]${NC} Deseja aguardar e monitorar o status automaticamente? [S/n]: ")" POLL_CHOICE
  POLL_CHOICE="${POLL_CHOICE:-S}"

  if [[ ! "$POLL_CHOICE" =~ ^[Ss]$ ]]; then
    log "Você pode verificar o status manualmente com:"
    echo -e "  ${BLUE}aws opensearch describe-domain --domain-name \"${DOMAIN_NAME}\" --query 'DomainStatus.Processing'${NC}"
    echo ""
    log "Após o domínio ficar ativo, execute:"
    echo -e "  ${BLUE}./configurar-ambiente.sh${NC}"
    echo -e "  ${BLUE}./testar-conexao.sh${NC}"
    return
  fi

  echo ""
  log "Monitorando status do domínio '${DOMAIN_NAME}'..."
  log "Verificando a cada 60 segundos. Pressione Ctrl+C para cancelar."
  echo ""

  local attempt=0
  local max_attempts=30  # 30 minutos máximo

  while [ $attempt -lt $max_attempts ]; do
    attempt=$((attempt + 1))
    local processing
    processing=$(aws opensearch describe-domain \
      --domain-name "${DOMAIN_NAME}" \
      --query 'DomainStatus.Processing' \
      --output text 2>/dev/null) || {
      warning "Não foi possível consultar o status. Tentando novamente..."
      sleep 60
      continue
    }

    if [ "$processing" = "False" ] || [ "$processing" = "false" ]; then
      echo ""
      success "Domínio '${DOMAIN_NAME}' está ATIVO!"
      echo ""

      # Obtém o endpoint
      local endpoint
      endpoint=$(aws opensearch describe-domain \
        --domain-name "${DOMAIN_NAME}" \
        --query 'DomainStatus.Endpoint' \
        --output text 2>/dev/null)

      if [ -n "$endpoint" ] && [ "$endpoint" != "None" ]; then
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}  Domínio Pronto!                       ${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo ""
        echo -e "  Endpoint: ${GREEN}https://${endpoint}${NC}"
        echo -e "  Usuário:  ${GREEN}${MASTER_USER}${NC}"
        echo ""
        echo -e "Próximos passos:"
        echo -e "  1. Configure as variáveis de ambiente:"
        echo -e "     ${BLUE}./configurar-ambiente.sh${NC}"
        echo -e "  2. Teste a conectividade:"
        echo -e "     ${BLUE}./testar-conexao.sh${NC}"
      fi
      return
    fi

    local elapsed=$((attempt * 1))
    log "Status: Processando... (${elapsed} min de ~15-20 min)"
    sleep 60
  done

  warning "Tempo máximo de espera atingido (30 min)."
  warning "Verifique o status no console AWS:"
  echo "  https://console.aws.amazon.com/aos/home"
}

# =============================================================================
# Execução principal
# =============================================================================

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Lab 0 — Criar Domínio OpenSearch      ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Este script auxilia na criação do seu domínio"
echo "Amazon OpenSearch Service via AWS CLI."
echo ""
echo -e "Configuração recomendada:"
echo -e "  • Instância:    ${GREEN}t3.small.search${NC}"
echo -e "  • Nós:          ${GREEN}1${NC}"
echo -e "  • EBS:          ${GREEN}10 GB (gp3)${NC}"
echo -e "  • Segurança:    ${GREEN}Fine-grained access control + HTTPS${NC}"
echo ""

# Passo 1: Validar pré-requisitos
check_aws_cli

# Passo 2: Coletar parâmetros
collect_parameters

# Passo 3: Confirmar criação
read -r -p "$(echo -e "${BLUE}[INFO]${NC} Confirma a criação do domínio? [S/n]: ")" CONFIRM
CONFIRM="${CONFIRM:-S}"

if [[ ! "$CONFIRM" =~ ^[Ss]$ ]]; then
  warning "Criação cancelada pelo usuário."
  exit 0
fi

# Passo 4: Criar domínio
create_domain

# Passo 5: Instruções de espera
show_wait_instructions

# Passo 6: Monitorar status (opcional)
poll_domain_status

echo ""
success "Script finalizado."
echo ""
