#!/bin/bash
# =============================================================================
# Validação da Infraestrutura — Curso OpenSearch
# Valida APENAS a infraestrutura provisionada pelo instrutor.
# NÃO valida existência de OpenSearch Domain (o aluno cria no Lab 0).
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_STACK_NAME="curso-opensearch-stack"
AWS_PROFILE=""
AWS_OPTS=""

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()     { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error()   { echo -e "${RED}❌ $1${NC}" >&2; }

# Parse de argumentos
STACK_NAME="${DEFAULT_STACK_NAME}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --stack-name) STACK_NAME="$2"; shift 2 ;;
    --profile)    AWS_PROFILE="$2"; AWS_OPTS="--profile ${2}"; shift 2 ;;
    -h|--help)
      echo "Uso: $0 [--stack-name NOME] [--profile PERFIL]"
      echo ""
      echo "Valida a infraestrutura provisionada pelo instrutor."
      echo "NÃO valida OpenSearch Domain (responsabilidade do aluno)."
      exit 0
      ;;
    *) error "Argumento desconhecido: $1"; exit 1 ;;
  esac
done

aws_cmd() {
  aws ${AWS_OPTS} "$@"
}

# Contadores
TOTAL=0
PASSED=0
FAILED=0

check() {
  local description="$1"
  local result="$2"
  TOTAL=$((TOTAL + 1))
  if [ "$result" -eq 0 ]; then
    PASSED=$((PASSED + 1))
    success "$description"
  else
    FAILED=$((FAILED + 1))
    error "$description"
  fi
}

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Validação da Infraestrutura — Curso OpenSearch${NC}"
echo -e "${BLUE}  Stack: ${STACK_NAME}${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# =============================================================================
# 1. Verificar pré-requisitos locais
# =============================================================================
log "Verificando pré-requisitos..."

command -v aws > /dev/null 2>&1
check "AWS CLI instalado" $?

command -v jq > /dev/null 2>&1
check "jq instalado" $?

command -v curl > /dev/null 2>&1
check "curl instalado" $?

aws_cmd sts get-caller-identity > /dev/null 2>&1
check "Credenciais AWS válidas" $?

echo ""

# =============================================================================
# 2. Verificar stack CloudFormation
# =============================================================================
log "Verificando stack CloudFormation..."

STACK_STATUS=$(aws_cmd cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$STACK_STATUS" = "NOT_FOUND" ]; then
  check "Stack '${STACK_NAME}' existe" 1
  echo ""
  error "Stack não encontrada. Execute deploy-curso.sh primeiro."
  exit 1
fi

check "Stack '${STACK_NAME}' existe" 0

if [ "$STACK_STATUS" = "CREATE_COMPLETE" ] || [ "$STACK_STATUS" = "UPDATE_COMPLETE" ]; then
  check "Stack em estado operacional (${STACK_STATUS})" 0
else
  check "Stack em estado operacional (${STACK_STATUS})" 1
fi

echo ""

# =============================================================================
# 3. Verificar instâncias EC2 dos alunos
# =============================================================================
log "Verificando instâncias EC2..."

INSTANCE_IDS=$(aws_cmd cloudformation describe-stack-resources \
  --stack-name "${STACK_NAME}" \
  --query 'StackResources[?ResourceType==`AWS::EC2::Instance`].PhysicalResourceId' \
  --output text 2>/dev/null || echo "")

if [ -z "$INSTANCE_IDS" ]; then
  check "Instâncias EC2 encontradas na stack" 1
else
  check "Instâncias EC2 encontradas na stack" 0

  IDS_ARRAY=()
  for id in $INSTANCE_IDS; do
    IDS_ARRAY+=("$id")
  done

  # Verificar se todas estão running
  ALL_RUNNING=true
  RUNNING_COUNT=0
  TOTAL_INSTANCES=${#IDS_ARRAY[@]}

  INSTANCES_INFO=$(aws_cmd ec2 describe-instances \
    --instance-ids "${IDS_ARRAY[@]}" \
    --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]' \
    --output text 2>/dev/null || echo "")

  while IFS=$'\t' read -r iid state ip; do
    if [ "$state" = "running" ]; then
      RUNNING_COUNT=$((RUNNING_COUNT + 1))
    else
      ALL_RUNNING=false
      warning "Instância ${iid} em estado: ${state}"
    fi
  done <<< "$INSTANCES_INFO"

  if [ "$ALL_RUNNING" = true ]; then
    check "Todas as ${TOTAL_INSTANCES} instâncias EC2 em estado 'running'" 0
  else
    check "Todas as instâncias EC2 em estado 'running' (${RUNNING_COUNT}/${TOTAL_INSTANCES})" 1
  fi
fi

echo ""

# =============================================================================
# 4. Verificar IAM Users dos alunos
# =============================================================================
log "Verificando IAM Users..."

IAM_USERS=$(aws_cmd cloudformation describe-stack-resources \
  --stack-name "${STACK_NAME}" \
  --query 'StackResources[?ResourceType==`AWS::IAM::User`].PhysicalResourceId' \
  --output text 2>/dev/null || echo "")

if [ -z "$IAM_USERS" ]; then
  check "IAM Users encontrados na stack" 1
else
  check "IAM Users encontrados na stack" 0

  USERS_OK=true
  for user in $IAM_USERS; do
    # Verificar se o user existe e tem access keys
    KEYS=$(aws_cmd iam list-access-keys \
      --user-name "$user" \
      --query 'AccessKeyMetadata[?Status==`Active`].AccessKeyId' \
      --output text 2>/dev/null || echo "")
    if [ -z "$KEYS" ]; then
      warning "IAM User '${user}' sem AccessKey ativa."
      USERS_OK=false
    fi
  done

  if [ "$USERS_OK" = true ]; then
    check "Todos os IAM Users possuem AccessKeys ativas" 0
  else
    check "Todos os IAM Users possuem AccessKeys ativas" 1
  fi
fi

echo ""

# =============================================================================
# 5. Verificar S3 bucket
# =============================================================================
log "Verificando S3 bucket..."

ACCOUNT_ID=$(aws_cmd sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
REGION=$(aws_cmd configure get region 2>/dev/null || echo "us-east-1")

# Tentar encontrar o bucket nos outputs da stack
S3_BUCKET=$(aws_cmd cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --query "Stacks[0].Outputs[?OutputKey=='S3BucketName'].OutputValue" \
  --output text 2>/dev/null || echo "")

# Fallback: tentar nome padrão
if [ -z "$S3_BUCKET" ] || [ "$S3_BUCKET" = "None" ]; then
  PREFIXO=$(aws_cmd cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --query "Stacks[0].Parameters[?ParameterKey=='Prefixo'].ParameterValue" \
    --output text 2>/dev/null || echo "curso-opensearch")
  S3_BUCKET="${PREFIXO}-labs-${ACCOUNT_ID}-${REGION}"
fi

if aws_cmd s3api head-bucket --bucket "${S3_BUCKET}" 2>/dev/null; then
  check "S3 bucket existe: ${S3_BUCKET}" 0

  # Verificar se setup-aluno.sh está no bucket
  if aws_cmd s3api head-object --bucket "${S3_BUCKET}" --key "setup-aluno.sh" 2>/dev/null; then
    check "setup-aluno.sh presente no S3 bucket" 0
  else
    check "setup-aluno.sh presente no S3 bucket" 1
  fi
else
  check "S3 bucket existe: ${S3_BUCKET}" 1
fi

echo ""

# =============================================================================
# 6. Verificar conectividade SSH (ao menos uma instância)
# =============================================================================
log "Verificando conectividade SSH..."

SSH_KEY="${SCRIPT_DIR}/.ssh-keys/${STACK_NAME%-stack}-key"
SSH_OK=false

if [ -f "$SSH_KEY" ]; then
  # Tentar SSH em ao menos uma instância
  if [ -n "$INSTANCES_INFO" ]; then
    FIRST_IP=$(echo "$INSTANCES_INFO" | head -1 | awk '{print $3}')
    if [ -n "$FIRST_IP" ] && [ "$FIRST_IP" != "None" ]; then
      if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes \
        "ec2-user@${FIRST_IP}" "echo OK" 2>/dev/null; then
        SSH_OK=true
      fi
    fi
  fi

  if [ "$SSH_OK" = true ]; then
    check "Conectividade SSH com instância EC2" 0
  else
    check "Conectividade SSH com instância EC2" 1
    warning "Verifique: Security Group, chave SSH, instância em estado 'running'"
  fi
else
  warning "Chave SSH não encontrada: ${SSH_KEY}"
  check "Conectividade SSH com instância EC2 (chave não encontrada)" 1
fi

echo ""

# =============================================================================
# Resultado final
# =============================================================================
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Resultado da Validação${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Total de verificações: ${TOTAL}"
echo -e "  ${GREEN}Aprovadas: ${PASSED}${NC}"
echo -e "  ${RED}Reprovadas: ${FAILED}${NC}"
echo ""

if [ "$FAILED" -eq 0 ]; then
  success "Ambiente pronto! Todos os testes passaram."
  echo ""
  echo -e "  ${YELLOW}Próximos passos:${NC}"
  echo -e "    1. Distribua as credenciais e chave SSH para os alunos"
  echo -e "    2. Cada aluno acessa sua EC2 via SSH"
  echo -e "    3. Cada aluno cria seu OpenSearch Domain no Lab 0"
  echo ""
  exit 0
else
  error "Ambiente com problemas. Corrija os erros acima e execute novamente."
  exit 1
fi
