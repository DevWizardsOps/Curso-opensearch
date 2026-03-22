#!/bin/bash
set -e

# =============================================================================
# Deploy Interativo do Curso — AWS OpenSearch Service (Módulo 6)
# Provisiona toda a infraestrutura AWS via CloudFormation de forma interativa.
# O instrutor executa este script para preparar o ambiente dos alunos.
# O template NÃO cria OpenSearch Domain — o aluno cria no Lab 0.
# =============================================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Funções de log com timestamp
log()     { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error()   { echo -e "${RED}❌ $1${NC}" >&2; }

# Diretório do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Valores padrão
PROFILE=""
AWS_OPTS=""

# =============================================================================
# Banner ASCII
# =============================================================================
show_banner() {
  echo ""
  echo -e "${CYAN}  ╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}  ║                                                      ║${NC}"
  echo -e "${CYAN}  ║   ${GREEN} ██████╗ ██████╗ ███████╗███╗   ██╗${CYAN}              ║${NC}"
  echo -e "${CYAN}  ║   ${GREEN}██╔═══██╗██╔══██╗██╔════╝████╗  ██║${CYAN}              ║${NC}"
  echo -e "${CYAN}  ║   ${GREEN}██║   ██║██████╔╝█████╗  ██╔██╗ ██║${CYAN}              ║${NC}"
  echo -e "${CYAN}  ║   ${GREEN}██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║${CYAN}              ║${NC}"
  echo -e "${CYAN}  ║   ${GREEN}╚██████╔╝██║     ███████╗██║ ╚████║${CYAN}              ║${NC}"
  echo -e "${CYAN}  ║   ${GREEN} ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝${CYAN}              ║${NC}"
  echo -e "${CYAN}  ║                                                      ║${NC}"
  echo -e "${CYAN}  ║   ${BLUE}AWS OpenSearch Service — Módulo 6${CYAN}                ║${NC}"
  echo -e "${CYAN}  ║   ${BLUE}Deploy Interativo do Curso${CYAN}                       ║${NC}"
  echo -e "${CYAN}  ║                                                      ║${NC}"
  echo -e "${CYAN}  ╚══════════════════════════════════════════════════════╝${NC}"
  echo ""
}

# =============================================================================
# Parse de argumentos (suporte a --profile)
# =============================================================================
while [[ $# -gt 0 ]]; do
  case $1 in
    --profile)  PROFILE="$2"; shift 2 ;;
    --help|-h)
      echo "Uso: $0 [--profile PROFILE]"
      echo ""
      echo "Opções:"
      echo "  --profile PROFILE   AWS CLI profile (opcional)"
      echo "  --help, -h          Exibe esta ajuda"
      exit 0
      ;;
    *) error "Argumento desconhecido: $1"; exit 1 ;;
  esac
done

if [ -n "$PROFILE" ]; then
  AWS_OPTS="--profile ${PROFILE}"
fi

# =============================================================================
# Verificar pré-requisitos
# =============================================================================
check_prerequisites() {
  log "Verificando pré-requisitos..."
  echo ""
  local missing=0

  # aws-cli
  if ! command -v aws &> /dev/null; then
    error "aws-cli não encontrado. Instale: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
    missing=1
  else
    success "aws-cli encontrado: $(aws --version 2>&1 | head -1)"
  fi

  # jq
  if ! command -v jq &> /dev/null; then
    error "jq não encontrado. Instale: sudo yum install jq"
    missing=1
  else
    success "jq encontrado: $(jq --version)"
  fi

  # curl
  if ! command -v curl &> /dev/null; then
    error "curl não encontrado."
    missing=1
  else
    success "curl encontrado"
  fi

  # ssh-keygen
  if ! command -v ssh-keygen &> /dev/null; then
    error "ssh-keygen não encontrado."
    missing=1
  else
    success "ssh-keygen encontrado"
  fi

  if [ "$missing" -eq 1 ]; then
    echo ""
    error "Pré-requisitos não atendidos. Corrija os erros acima e tente novamente."
    exit 1
  fi

  echo ""

  # Credenciais AWS
  log "Verificando credenciais AWS..."
  local identity
  identity=$(aws sts get-caller-identity ${AWS_OPTS} 2>&1) || {
    error "Credenciais AWS inválidas ou não configuradas."
    error "Detalhes: ${identity}"
    error "Configure com: aws configure ${PROFILE:+--profile ${PROFILE}}"
    exit 1
  }

  ACCOUNT_ID=$(echo "$identity" | jq -r '.Account')
  USER_ARN=$(echo "$identity" | jq -r '.Arn')
  REGION=$(aws configure get region ${AWS_OPTS} 2>/dev/null || echo "us-east-1")

  success "Credenciais válidas"
  echo -e "  Conta:  ${ACCOUNT_ID}"
  echo -e "  ARN:    ${USER_ARN}"
  echo -e "  Região: ${REGION}"
  echo ""
}

# =============================================================================
# Prompts interativos
# =============================================================================
interactive_prompts() {
  echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  Configuração do Curso${NC}"
  echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
  echo ""

  # 1. Número de alunos
  read -rp "$(echo -e "${BLUE}[?]${NC} Número de alunos (1-30) [5]: ")" NUM_ALUNOS
  NUM_ALUNOS="${NUM_ALUNOS:-5}"
  if ! [[ "$NUM_ALUNOS" =~ ^[0-9]+$ ]] || [ "$NUM_ALUNOS" -lt 1 ] || [ "$NUM_ALUNOS" -gt 30 ]; then
    error "Número de alunos deve ser entre 1 e 30."
    exit 1
  fi
  success "Alunos: ${NUM_ALUNOS}"
  echo ""

  # 2. Prefixo do curso
  read -rp "$(echo -e "${BLUE}[?]${NC} Prefixo do curso [curso-opensearch]: ")" PREFIXO
  PREFIXO="${PREFIXO:-curso-opensearch}"
  success "Prefixo: ${PREFIXO}"
  echo ""

  # 3. Nome da stack CloudFormation
  read -rp "$(echo -e "${BLUE}[?]${NC} Nome da stack CloudFormation [${PREFIXO}-stack]: ")" STACK_NAME
  STACK_NAME="${STACK_NAME:-${PREFIXO}-stack}"
  success "Stack: ${STACK_NAME}"
  echo ""

  # 4. CIDR de acesso (auto-detect IP)
  local my_ip=""
  my_ip=$(curl -s --max-time 5 https://checkip.amazonaws.com 2>/dev/null | tr -d '\n' || echo "")
  local cidr_default="0.0.0.0/0"
  if [ -n "$my_ip" ]; then
    cidr_default="${my_ip}/32"
    log "IP público detectado: ${my_ip}"
  fi
  read -rp "$(echo -e "${BLUE}[?]${NC} CIDR de acesso SSH [${cidr_default}]: ")" ACCESS_CIDR
  ACCESS_CIDR="${ACCESS_CIDR:-${cidr_default}}"
  success "CIDR: ${ACCESS_CIDR}"
  echo ""

  # 5. Senha do console AWS para os alunos
  echo -e "${YELLOW}Configuração de Senha do Console:${NC}"
  read -rp "$(echo -e "${BLUE}[?]${NC} Senha padrão para os alunos [Extractta@2026]: ")" CONSOLE_PASSWORD
  CONSOLE_PASSWORD="${CONSOLE_PASSWORD:-Extractta@2026}"

  # Validar senha (mínimo 8 caracteres)
  while [ ${#CONSOLE_PASSWORD} -lt 8 ]; do
    error "Senha deve ter no mínimo 8 caracteres"
    read -rp "$(echo -e "${BLUE}[?]${NC} Senha padrão para os alunos [Extractta@2026]: ")" CONSOLE_PASSWORD
    CONSOLE_PASSWORD="${CONSOLE_PASSWORD:-Extractta@2026}"
  done
  success "Senha configurada (será armazenada no Secrets Manager)"
  echo ""

  # Nomes derivados
  S3_BUCKET="${PREFIXO}-labs-${ACCOUNT_ID}-${REGION}"
  SECRET_NAME="${PREFIXO}-senha"
  SSH_KEY_NAME="${PREFIXO}-key"
  TEMPLATE_FILE="${SCRIPT_DIR}/template-opensearch.yaml"
  SSH_KEY_DIR="${SCRIPT_DIR}/.ssh-keys"
  SSH_PRIVATE_KEY="${SSH_KEY_DIR}/${SSH_KEY_NAME}"
  SSH_PUBLIC_KEY="${SSH_KEY_DIR}/${SSH_KEY_NAME}.pub"
  HTML_REPORT="${SCRIPT_DIR}/relatorio-acesso.html"
}

# =============================================================================
# Verificar se stack já existe (create vs update)
# =============================================================================
check_existing_stack() {
  log "Verificando se a stack '${STACK_NAME}' já existe..."
  STACK_EXISTS=false
  local stack_status
  stack_status=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    ${AWS_OPTS} --region "${REGION}" \
    --query 'Stacks[0].StackStatus' \
    --output text 2>/dev/null) || {
    log "Stack não encontrada. Será criada."
    return 0
  }

  if [ -n "$stack_status" ] && [ "$stack_status" != "None" ]; then
    STACK_EXISTS=true
    warning "Stack '${STACK_NAME}' já existe com status: ${stack_status}"
    if [[ "$stack_status" == *"FAILED"* ]] || [[ "$stack_status" == *"ROLLBACK"* ]]; then
      error "Stack em estado de falha (${stack_status}). Execute cleanup antes de recriar."
      error "  ./manage-curso.sh cleanup --stack-name ${STACK_NAME}"
      exit 1
    fi
    log "A stack será atualizada."
  fi
  echo ""
}

# =============================================================================
# Gerar par de chaves SSH
# =============================================================================
generate_ssh_keys() {
  log "Gerando par de chaves SSH..."

  mkdir -p "${SSH_KEY_DIR}"

  if [ -f "${SSH_PRIVATE_KEY}" ]; then
    warning "Chave SSH já existe: ${SSH_PRIVATE_KEY}"
    read -rp "$(echo -e "${BLUE}[?]${NC} Sobrescrever? (s/N): ")" overwrite
    if [[ ! "$overwrite" =~ ^[sS]$ ]]; then
      log "Usando chave existente."
      echo ""
      return 0
    fi
  fi

  ssh-keygen -t rsa -b 4096 -f "${SSH_PRIVATE_KEY}" -N "" -C "${PREFIXO}-aluno" -q
  chmod 600 "${SSH_PRIVATE_KEY}"
  chmod 644 "${SSH_PUBLIC_KEY}"

  success "Par de chaves SSH gerado:"
  echo -e "  Privada: ${SSH_PRIVATE_KEY}"
  echo -e "  Pública: ${SSH_PUBLIC_KEY}"
  echo ""

  # Importar chave pública para AWS
  log "Importando chave pública para AWS EC2..."
  aws ec2 import-key-pair \
    --key-name "${SSH_KEY_NAME}" \
    --public-key-material "fileb://${SSH_PUBLIC_KEY}" \
    ${AWS_OPTS} --region "${REGION}" 2>/dev/null || {
    # Se já existe, deleta e reimporta
    warning "Key pair '${SSH_KEY_NAME}' já existe no AWS. Substituindo..."
    aws ec2 delete-key-pair --key-name "${SSH_KEY_NAME}" \
      ${AWS_OPTS} --region "${REGION}" 2>/dev/null || true
    aws ec2 import-key-pair \
      --key-name "${SSH_KEY_NAME}" \
      --public-key-material "fileb://${SSH_PUBLIC_KEY}" \
      ${AWS_OPTS} --region "${REGION}"
  }
  success "Chave pública importada para AWS: ${SSH_KEY_NAME}"

  # Salvar informações da chave SSH para uso posterior (padrão ElastiCache)
  S3_KEY_PATH="$(date +%Y)/$(date +%m)/$(date +%d)/${SSH_KEY_NAME}.pem"
  S3_KEYS_BUCKET="${STACK_NAME}-keys-${ACCOUNT_ID}"
  S3_CONSOLE_URL="https://s3.console.aws.amazon.com/s3/object/${S3_KEYS_BUCKET}?region=${REGION}&prefix=${S3_KEY_PATH}"

  echo "S3_BUCKET=${S3_KEYS_BUCKET}" > "${SCRIPT_DIR}/.ssh-key-info"
  echo "S3_KEY_PATH=${S3_KEY_PATH}" >> "${SCRIPT_DIR}/.ssh-key-info"
  echo "S3_CONSOLE_URL=${S3_CONSOLE_URL}" >> "${SCRIPT_DIR}/.ssh-key-info"

  echo ""
}

# =============================================================================
# Criar ou atualizar secret no Secrets Manager
# =============================================================================
setup_secrets_manager() {
  log "Configurando Secrets Manager..."

  local secret_value="{\"password\":\"${CONSOLE_PASSWORD}\"}"

  # Verifica se o secret já existe
  local secret_exists=false
  aws secretsmanager describe-secret \
    --secret-id "${SECRET_NAME}" \
    ${AWS_OPTS} --region "${REGION}" > /dev/null 2>&1 && secret_exists=true

  if [ "$secret_exists" = true ]; then
    # Verifica se está marcado para deleção
    local deletion_date
    deletion_date=$(aws secretsmanager describe-secret \
      --secret-id "${SECRET_NAME}" \
      ${AWS_OPTS} --region "${REGION}" \
      --query 'DeletedDate' --output text 2>/dev/null || echo "None")

    if [ "$deletion_date" != "None" ] && [ -n "$deletion_date" ]; then
      log "Secret marcado para deleção. Restaurando..."
      aws secretsmanager restore-secret \
        --secret-id "${SECRET_NAME}" \
        ${AWS_OPTS} --region "${REGION}" > /dev/null
      success "Secret restaurado: ${SECRET_NAME}"
    fi

    log "Atualizando secret existente..."
    aws secretsmanager put-secret-value \
      --secret-id "${SECRET_NAME}" \
      --secret-string "${secret_value}" \
      ${AWS_OPTS} --region "${REGION}" > /dev/null
    success "Secret atualizado: ${SECRET_NAME}"
  else
    log "Criando novo secret..."
    aws secretsmanager create-secret \
      --name "${SECRET_NAME}" \
      --description "Senha do console AWS para alunos do Curso OpenSearch" \
      --secret-string "${secret_value}" \
      ${AWS_OPTS} --region "${REGION}" > /dev/null
    success "Secret criado: ${SECRET_NAME}"
  fi
  echo ""
}

# =============================================================================
# Criar S3 bucket e fazer upload de arquivos
# =============================================================================
setup_s3_bucket() {
  log "Configurando S3 bucket..."

  # Criar bucket se não existir
  if aws s3api head-bucket --bucket "${S3_BUCKET}" ${AWS_OPTS} --region "${REGION}" 2>/dev/null; then
    log "Bucket já existe: ${S3_BUCKET}"
  else
    log "Criando bucket: ${S3_BUCKET}"
    if [ "${REGION}" = "us-east-1" ]; then
      aws s3api create-bucket \
        --bucket "${S3_BUCKET}" \
        ${AWS_OPTS} --region "${REGION}" > /dev/null
    else
      aws s3api create-bucket \
        --bucket "${S3_BUCKET}" \
        --create-bucket-configuration LocationConstraint="${REGION}" \
        ${AWS_OPTS} --region "${REGION}" > /dev/null
    fi
    success "Bucket criado: ${S3_BUCKET}"
  fi

  # Upload da chave privada SSH para S3 (para distribuição aos alunos)
  log "Fazendo upload da chave SSH privada para S3..."

  # Criar bucket de chaves separado (padrão ElastiCache)
  if aws s3api head-bucket --bucket "${S3_KEYS_BUCKET}" ${AWS_OPTS} --region "${REGION}" 2>/dev/null; then
    log "Bucket de chaves já existe: ${S3_KEYS_BUCKET}"
  else
    log "Criando bucket de chaves: ${S3_KEYS_BUCKET}"
    if [ "${REGION}" = "us-east-1" ]; then
      aws s3api create-bucket \
        --bucket "${S3_KEYS_BUCKET}" \
        ${AWS_OPTS} --region "${REGION}" > /dev/null
    else
      aws s3api create-bucket \
        --bucket "${S3_KEYS_BUCKET}" \
        --create-bucket-configuration LocationConstraint="${REGION}" \
        ${AWS_OPTS} --region "${REGION}" > /dev/null
    fi

    # Bloquear acesso público ao bucket de chaves
    aws s3api put-public-access-block \
      --bucket "${S3_KEYS_BUCKET}" \
      --public-access-block-configuration \
      "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
      ${AWS_OPTS} --region "${REGION}" > /dev/null
  fi

  aws s3 cp "${SSH_PRIVATE_KEY}" "s3://${S3_KEYS_BUCKET}/${S3_KEY_PATH}" \
    --metadata "stack-name=${STACK_NAME},created-date=$(date -Iseconds)" \
    ${AWS_OPTS} --region "${REGION}" > /dev/null
  success "Chave SSH enviada para: s3://${S3_KEYS_BUCKET}/${S3_KEY_PATH}"

  # Upload do setup-aluno.sh para S3
  local setup_script="${SCRIPT_DIR}/setup-aluno.sh"
  if [ ! -f "${setup_script}" ]; then
    error "Script setup-aluno.sh não encontrado em: ${setup_script}"
    exit 1
  fi
  log "Fazendo upload do setup-aluno.sh para S3..."
  aws s3 cp "${setup_script}" "s3://${S3_BUCKET}/setup-aluno.sh" \
    ${AWS_OPTS} --region "${REGION}" > /dev/null
  success "setup-aluno.sh enviado para: s3://${S3_BUCKET}/setup-aluno.sh"

  echo ""
}

# =============================================================================
# Gerar template CloudFormation
# =============================================================================
generate_template() {
  log "Gerando template CloudFormation com ${NUM_ALUNOS} alunos..."

  bash "${SCRIPT_DIR}/gerar-template.sh" "${NUM_ALUNOS}" \
    --prefixo "${PREFIXO}" \
    --bucket "${S3_BUCKET}" \
    --secret "${SECRET_NAME}" \
    --ssh-key "${SSH_KEY_NAME}" \
    --cidr "${ACCESS_CIDR}" \
    --output "${TEMPLATE_FILE}"

  if [ ! -f "${TEMPLATE_FILE}" ]; then
    error "Falha ao gerar template. Arquivo não encontrado: ${TEMPLATE_FILE}"
    exit 1
  fi

  success "Template gerado: ${TEMPLATE_FILE}"
  echo ""
}

# =============================================================================
# Confirmação antes do deploy
# =============================================================================
confirm_deploy() {
  echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  Resumo da Configuração${NC}"
  echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "  Alunos:          ${GREEN}${NUM_ALUNOS}${NC}"
  echo -e "  Prefixo:         ${GREEN}${PREFIXO}${NC}"
  echo -e "  Stack:           ${GREEN}${STACK_NAME}${NC}"
  echo -e "  Região:          ${GREEN}${REGION}${NC}"
  echo -e "  CIDR:            ${GREEN}${ACCESS_CIDR}${NC}"
  echo -e "  S3 Bucket:       ${GREEN}${S3_BUCKET}${NC}"
  echo -e "  Secret:          ${GREEN}${SECRET_NAME}${NC}"
  echo -e "  SSH Key:         ${GREEN}${SSH_KEY_NAME}${NC}"
  echo -e "  Conta AWS:       ${GREEN}${ACCOUNT_ID}${NC}"
  if [ "$STACK_EXISTS" = true ]; then
    echo -e "  Ação:            ${YELLOW}ATUALIZAR stack existente${NC}"
  else
    echo -e "  Ação:            ${GREEN}CRIAR nova stack${NC}"
  fi
  echo ""
  echo -e "  ${YELLOW}Recursos que serão criados:${NC}"
  echo -e "    • VPC + Subnets (pública + privada)"
  echo -e "    • Internet Gateway + NAT Gateway"
  echo -e "    • Security Group (SSH porta 22)"
  echo -e "    • IAM Group + Policy (OpenSearch, EC2, CloudWatch, S3, KMS, STS)"
  echo -e "    • IAM Role para EC2 (acesso S3)"
  echo -e "    • ${NUM_ALUNOS}x EC2 Instance (t3.micro)"
  echo -e "    • ${NUM_ALUNOS}x IAM User + AccessKey + LoginProfile"
  echo ""
  echo -e "  ${YELLOW}NOTA: O template NÃO cria OpenSearch Domain.${NC}"
  echo -e "  ${YELLOW}Cada aluno cria seu próprio domínio no Lab 0.${NC}"
  echo ""

  read -rp "$(echo -e "${BLUE}[?]${NC} Confirma o deploy? (s/N): ")" confirm
  if [[ ! "$confirm" =~ ^[sS]$ ]]; then
    warning "Deploy cancelado pelo usuário."
    exit 0
  fi
  echo ""
}

# =============================================================================
# Deploy da stack CloudFormation
# =============================================================================
deploy_stack() {
  log "Iniciando deploy da stack CloudFormation..."

  # Verificar tamanho do template (> 50KB precisa upload para S3)
  local template_size
  template_size=$(stat -f%z "${TEMPLATE_FILE}" 2>/dev/null || stat -c%s "${TEMPLATE_FILE}" 2>/dev/null || wc -c < "${TEMPLATE_FILE}")

  local cf_template_arg=""
  if [ "$template_size" -gt 51200 ]; then
    warning "Template excede 50KB (${template_size} bytes). Fazendo upload para S3..."
    aws s3 cp "${TEMPLATE_FILE}" "s3://${S3_BUCKET}/template-opensearch.yaml" \
      ${AWS_OPTS} --region "${REGION}" > /dev/null
    cf_template_arg="--template-url https://${S3_BUCKET}.s3.amazonaws.com/template-opensearch.yaml"
    success "Template enviado para S3"
  else
    cf_template_arg="--template-body file://${TEMPLATE_FILE}"
  fi

  # Validar template
  log "Validando template..."
  aws cloudformation validate-template \
    ${cf_template_arg} \
    ${AWS_OPTS} --region "${REGION}" > /dev/null 2>&1 || {
    error "Template inválido. Verifique o arquivo: ${TEMPLATE_FILE}"
    exit 1
  }
  success "Template válido"
  echo ""

  # Parâmetros do CloudFormation
  local cf_params="ParameterKey=NumAlunos,ParameterValue=${NUM_ALUNOS}"
  cf_params="${cf_params} ParameterKey=Prefixo,ParameterValue=${PREFIXO}"
  cf_params="${cf_params} ParameterKey=S3BucketName,ParameterValue=${S3_BUCKET}"
  cf_params="${cf_params} ParameterKey=SecretName,ParameterValue=${SECRET_NAME}"
  cf_params="${cf_params} ParameterKey=SSHKeyName,ParameterValue=${SSH_KEY_NAME}"
  cf_params="${cf_params} ParameterKey=AccessCIDR,ParameterValue=${ACCESS_CIDR}"

  if [ "$STACK_EXISTS" = true ]; then
    log "Atualizando stack existente: ${STACK_NAME}..."
    aws cloudformation update-stack \
      --stack-name "${STACK_NAME}" \
      ${cf_template_arg} \
      --parameters ${cf_params} \
      --capabilities CAPABILITY_NAMED_IAM \
      ${AWS_OPTS} --region "${REGION}" > /dev/null 2>&1 || {
      local err=$?
      # "No updates are to be performed" não é erro real
      if aws cloudformation describe-stacks --stack-name "${STACK_NAME}" \
        ${AWS_OPTS} --region "${REGION}" > /dev/null 2>&1; then
        warning "Nenhuma atualização necessária (stack já está atualizada)."
        return 0
      fi
      error "Falha ao atualizar a stack."
      exit 1
    }
    log "Aguardando conclusão da atualização..."
    aws cloudformation wait stack-update-complete \
      --stack-name "${STACK_NAME}" \
      ${AWS_OPTS} --region "${REGION}" || {
      error "Timeout ou falha na atualização da stack."
      error "Verifique: aws cloudformation describe-stack-events --stack-name ${STACK_NAME} ${AWS_OPTS} --region ${REGION}"
      exit 1
    }
  else
    log "Criando nova stack: ${STACK_NAME}..."
    aws cloudformation create-stack \
      --stack-name "${STACK_NAME}" \
      ${cf_template_arg} \
      --parameters ${cf_params} \
      --capabilities CAPABILITY_NAMED_IAM \
      ${AWS_OPTS} --region "${REGION}" > /dev/null
    log "Aguardando conclusão da criação (pode levar 5-10 minutos)..."
    aws cloudformation wait stack-create-complete \
      --stack-name "${STACK_NAME}" \
      ${AWS_OPTS} --region "${REGION}" || {
      error "Timeout ou falha na criação da stack."
      error "Verifique: aws cloudformation describe-stack-events --stack-name ${STACK_NAME} ${AWS_OPTS} --region ${REGION}"
      exit 1
    }
  fi

  success "Stack '${STACK_NAME}' deployada com sucesso!"
  echo ""
}

# =============================================================================
# Gerar HTML Report
# =============================================================================
generate_html_report() {
  log "Gerando relatório HTML de acesso..."

  # Obter outputs da stack
  local outputs
  outputs=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    ${AWS_OPTS} --region "${REGION}" \
    --query 'Stacks[0].Outputs' \
    --output json 2>/dev/null) || {
    warning "Não foi possível obter outputs da stack."
    return 0
  }

  local console_url="https://${ACCOUNT_ID}.signin.aws.amazon.com/console"
  local timestamp_file="relatorio-$(date +%Y%m%d-%H%M%S).html"

  # Criar HTML completo localmente
  {
    cat << 'HTMLEOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Curso OpenSearch — Informações de Acesso</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            min-height: 100vh;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 15px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }
        .header h1 { font-size: 2.5em; margin-bottom: 10px; }
        .header p { font-size: 1.2em; opacity: 0.9; }
        .content { padding: 40px; }
        .info-section {
            background: #f8f9fa;
            border-left: 4px solid #667eea;
            padding: 20px;
            margin-bottom: 20px;
            border-radius: 8px;
        }
        .info-section h2 { color: #667eea; margin-bottom: 15px; font-size: 1.5em; }
        .info-item {
            margin: 10px 0;
            padding: 10px;
            background: white;
            border-radius: 5px;
        }
        .info-item strong {
            color: #333;
            display: inline-block;
            min-width: 180px;
        }
        .warning-box {
            background: #fff3cd;
            border: 2px solid #ffc107;
            border-radius: 8px;
            padding: 20px;
            margin: 20px 0;
        }
        .warning-box h3 { color: #856404; margin-bottom: 10px; }
        .warning-box p { color: #856404; line-height: 1.6; }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(450px, 1fr));
            gap: 20px;
            margin-top: 20px;
        }
        .aluno-card {
            background: white;
            border: 2px solid #e0e0e0;
            border-radius: 10px;
            padding: 25px;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        .aluno-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 25px rgba(0,0,0,0.1);
            border-color: #667eea;
        }
        .aluno-card h3 {
            color: #667eea;
            margin-bottom: 20px;
            font-size: 1.8em;
            border-bottom: 2px solid #667eea;
            padding-bottom: 10px;
        }
        .code-block {
            background: #2d2d2d;
            color: #f8f8f2;
            padding: 15px;
            border-radius: 5px;
            font-family: 'Courier New', monospace;
            margin: 10px 0;
            overflow-x: auto;
            font-size: 0.9em;
        }
        .badge {
            display: inline-block;
            padding: 5px 12px;
            background: #667eea;
            color: white;
            border-radius: 20px;
            font-size: 0.9em;
            margin-right: 10px;
            font-weight: bold;
        }
        .badge-warning {
            background: #ffc107;
            color: #333;
        }
        .footer {
            background: #f8f9fa;
            padding: 20px;
            text-align: center;
            color: #666;
            border-top: 1px solid #e0e0e0;
        }
        @media print {
            body { background: white; padding: 0; }
            .container { box-shadow: none; }
            .aluno-card { page-break-inside: avoid; }
        }
        @media (max-width: 768px) {
            .grid { grid-template-columns: 1fr; }
            .info-item strong { display: block; margin-bottom: 5px; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔍 Curso AWS OpenSearch Service — Módulo 6</h1>
            <p>Informações de Acesso ao Ambiente AWS</p>
HTMLEOF

    echo "            <p>Gerado em: $(date '+%d/%m/%Y às %H:%M:%S')</p>"
    echo "        </div>"
    echo "        <div class=\"content\">"

    # Warning box sobre senha
    echo "            <div class=\"warning-box\">"
    echo "                <h3>🔐 Informação Importante sobre Senhas</h3>"
    echo "                <p>A senha do console AWS está armazenada no <strong>AWS Secrets Manager</strong> e será fornecida pelo instrutor.</p>"
    echo "                <p>Por questões de segurança, a senha <strong>NÃO</strong> está incluída neste documento.</p>"
    echo "            </div>"

    # Informações gerais
    echo "            <div class=\"info-section\">"
    echo "                <h2>📋 Informações Gerais</h2>"
    echo "                <div class=\"info-item\"><strong>Stack Name:</strong> ${STACK_NAME}</div>"
    echo "                <div class=\"info-item\"><strong>Região AWS:</strong> ${REGION}</div>"
    echo "                <div class=\"info-item\"><strong>Account ID:</strong> ${ACCOUNT_ID}</div>"
    echo "                <div class=\"info-item\"><strong>Número de Alunos:</strong> ${NUM_ALUNOS}</div>"
    echo "            </div>"

    # Console AWS
    echo "            <div class=\"info-section\">"
    echo "                <h2>🌐 Acesso ao Console AWS</h2>"
    echo "                <div class=\"info-item\">"
    echo "                    <strong>URL de Login:</strong>"
    echo "                    <a href=\"${console_url}\" target=\"_blank\">${console_url}</a>"
    echo "                </div>"
    echo "                <div class=\"info-item\">"
    echo "                    <strong>Padrão de Usuário:</strong> ${PREFIXO}-alunoXX (onde XX = 01, 02, 03...)"
    echo "                </div>"
    echo "                <div class=\"info-item\">"
    echo "                    <strong>Senha:</strong> <span class=\"badge badge-warning\">Será fornecida pelo instrutor</span>"
    echo "                </div>"
    echo "            </div>"

    # Chave SSH
    if [ -f "${SCRIPT_DIR}/.ssh-key-info" ]; then
      source "${SCRIPT_DIR}/.ssh-key-info"
      echo "            <div class=\"info-section\">"
      echo "                <h2>🔑 Chave SSH</h2>"
      echo "                <div class=\"info-item\">"
      echo "                    <strong>Nome do Arquivo:</strong> ${SSH_KEY_NAME}.pem"
      echo "                </div>"
      echo "                <div class=\"info-item\">"
      echo "                    <strong>Download via Console S3:</strong><br>"
      echo "                    <a href=\"${S3_CONSOLE_URL}\" target=\"_blank\">Clique aqui para baixar no Console AWS</a>"
      echo "                </div>"
      echo "                <div class=\"info-item\">"
      echo "                    <strong>Download via AWS CLI:</strong>"
      echo "                    <div class=\"code-block\">aws s3 cp s3://${S3_BUCKET}/${S3_KEY_PATH} ${SSH_KEY_NAME}.pem<br>chmod 400 ${SSH_KEY_NAME}.pem</div>"
      echo "                </div>"
      echo "            </div>"
    else
      echo "            <div class=\"info-section\">"
      echo "                <h2>🔑 Chave SSH</h2>"
      echo "                <div class=\"info-item\">"
      echo "                    <strong>Nome do Arquivo:</strong> ${SSH_KEY_NAME}.pem"
      echo "                </div>"
      echo "                <div class=\"info-item\">"
      echo "                    <strong>Localização:</strong> Arquivo local — será distribuído pelo instrutor"
      echo "                </div>"
      echo "            </div>"
    fi

    # Cards dos alunos
    echo "            <h2 style=\"color: #667eea; margin: 30px 0 20px 0; font-size: 2em;\">👨‍🎓 Informações dos Alunos</h2>"
    echo "            <div class=\"grid\">"

    for (( i=1; i<=NUM_ALUNOS; i++ )); do
      local ip
      ip=$(echo "$outputs" | jq -r ".[] | select(.OutputKey==\"EC2Aluno${i}IP\") | .OutputValue" 2>/dev/null || echo "N/A")
      local username="${PREFIXO}-aluno$(printf '%02d' $i)"

      echo "                <div class=\"aluno-card\">"
      echo "                    <h3>👤 Aluno ${i} — ${username}</h3>"
      echo "                    <div class=\"info-item\">"
      echo "                        <span class=\"badge\">Console AWS</span><br>"
      echo "                        <strong>Usuário IAM:</strong> ${username}"
      echo "                    </div>"
      echo "                    <div class=\"info-item\">"
      echo "                        <span class=\"badge\">Instância EC2</span><br>"
      echo "                        <strong>IP Público:</strong> <code>${ip}</code>"
      echo "                    </div>"
      echo "                    <div class=\"info-item\">"
      echo "                        <strong>Comando SSH:</strong>"
      echo "                        <div class=\"code-block\">ssh -i ${SSH_KEY_NAME}.pem ${username}@${ip}</div>"
      echo "                    </div>"
      echo "                </div>"
    done

    echo "            </div>"

    # Instruções importantes
    echo "            <div class=\"info-section\" style=\"margin-top: 30px;\">"
    echo "                <h2>📚 Instruções Importantes</h2>"
    echo "                <div class=\"info-item\">"
    echo "                    <strong>1. Primeiro Acesso:</strong> Faça login no console AWS com seu usuário e a senha fornecida pelo instrutor."
    echo "                </div>"
    echo "                <div class=\"info-item\">"
    echo "                    <strong>2. Chave SSH:</strong> Baixe a chave SSH e configure as permissões corretas (chmod 400)."
    echo "                </div>"
    echo "                <div class=\"info-item\">"
    echo "                    <strong>3. Conexão EC2:</strong> Use o comando SSH fornecido para conectar à sua instância."
    echo "                </div>"
    echo "                <div class=\"info-item\">"
    echo "                    <strong>4. Lab 0:</strong> Navegue até <code>cd ~/Curso-opensearch/modulo6-lab/lab0-setup/</code> e crie seu OpenSearch Domain."
    echo "                </div>"
    echo "                <div class=\"info-item\">"
    echo "                    <strong>5. Ambiente:</strong> Todas as ferramentas (AWS CLI, curl, jq) já estão instaladas na EC2."
    echo "                </div>"
    echo "            </div>"

    # Footer
    echo "        </div>"
    echo "        <div class=\"footer\">"
    echo "            <p><strong>🔍 Curso AWS OpenSearch Service — Módulo 6 — Extractta</strong></p>"
    echo "            <p>Para dúvidas ou problemas, entre em contato com o instrutor</p>"
    echo "            <p style=\"margin-top: 10px; font-size: 0.9em; color: #999;\">Documento gerado automaticamente — Não compartilhe com terceiros</p>"
    echo "        </div>"
    echo "    </div>"
    echo "</body>"
    echo "</html>"

  } > "${HTML_REPORT}"

  success "Relatório HTML gerado: ${HTML_REPORT}"

  # Upload do HTML para S3 — bucket SEPARADO para relatórios (padrão ElastiCache)
  log "Publicando relatório como S3 website..."

  REPORT_BUCKET="${STACK_NAME}-reports-${ACCOUNT_ID}"

  # Criar bucket de relatórios se não existir
  if aws s3api head-bucket --bucket "${REPORT_BUCKET}" ${AWS_OPTS} --region "${REGION}" 2>/dev/null; then
    log "Bucket de relatórios já existe: ${REPORT_BUCKET}"
  else
    log "Criando bucket de relatórios: ${REPORT_BUCKET}"
    if [ "${REGION}" = "us-east-1" ]; then
      aws s3api create-bucket \
        --bucket "${REPORT_BUCKET}" \
        ${AWS_OPTS} --region "${REGION}" > /dev/null
    else
      aws s3api create-bucket \
        --bucket "${REPORT_BUCKET}" \
        --create-bucket-configuration LocationConstraint="${REGION}" \
        ${AWS_OPTS} --region "${REGION}" > /dev/null
    fi
  fi

  # Configurar bucket como website estático
  aws s3 website "s3://${REPORT_BUCKET}" \
    --index-document index.html \
    --error-document error.html \
    ${AWS_OPTS} --region "${REGION}"

  # Desbloquear acesso público
  aws s3api put-public-access-block \
    --bucket "${REPORT_BUCKET}" \
    --public-access-block-configuration \
    "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false" \
    ${AWS_OPTS} --region "${REGION}" > /dev/null

  # Aplicar política de bucket para acesso público de leitura
  cat > /tmp/report-bucket-policy.json << POLICYEOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${REPORT_BUCKET}/*"
        }
    ]
}
POLICYEOF

  aws s3api put-bucket-policy \
    --bucket "${REPORT_BUCKET}" \
    --policy file:///tmp/report-bucket-policy.json \
    ${AWS_OPTS} --region "${REGION}" > /dev/null

  rm -f /tmp/report-bucket-policy.json

  # Upload como index.html (sempre a versão mais recente) e versionado
  aws s3 cp "${HTML_REPORT}" "s3://${REPORT_BUCKET}/index.html" \
    --content-type "text/html; charset=utf-8" \
    --metadata "stack-name=${STACK_NAME},created-date=$(date -Iseconds)" \
    ${AWS_OPTS} --region "${REGION}" > /dev/null

  aws s3 cp "${HTML_REPORT}" "s3://${REPORT_BUCKET}/${timestamp_file}" \
    --content-type "text/html; charset=utf-8" \
    --metadata "stack-name=${STACK_NAME},created-date=$(date -Iseconds)" \
    ${AWS_OPTS} --region "${REGION}" > /dev/null

  # Gerar URLs
  WEBSITE_URL="https://${REPORT_BUCKET}.s3-${REGION}.amazonaws.com"
  REPORT_URL="${WEBSITE_URL}/${timestamp_file}"

  success "Relatório publicado no S3!"
  echo -e "  Website: ${WEBSITE_URL}"
  echo -e "  Relatório: ${REPORT_URL}"
  echo ""
}

# =============================================================================
# Resumo final no terminal
# =============================================================================
show_summary() {
  local console_url="https://${ACCOUNT_ID}.signin.aws.amazon.com/console"

  # Obter outputs da stack
  local outputs
  outputs=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    ${AWS_OPTS} --region "${REGION}" \
    --query 'Stacks[0].Outputs' \
    --output json 2>/dev/null) || outputs="[]"

  echo ""
  echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}           ✅ DEPLOY CONCLUÍDO COM SUCESSO!                    ${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
  echo ""

  # Relatório web
  if [ -n "${WEBSITE_URL:-}" ]; then
    echo -e "${BLUE}🌐 RELATÓRIO WEB (Sempre atualizado):${NC}"
    echo -e "${YELLOW}   ${WEBSITE_URL}${NC}"
    echo ""
    echo -e "${BLUE}📄 RELATÓRIO ESPECÍFICO (Esta execução):${NC}"
    echo -e "${YELLOW}   ${REPORT_URL}${NC}"
    echo ""
  fi

  # Senha no Secrets Manager
  echo -e "${BLUE}🔐 SENHA DO CONSOLE (Secrets Manager):${NC}"
  echo -e "${YELLOW}   https://console.aws.amazon.com/secretsmanager/home?region=${REGION}#!/secret?name=${SECRET_NAME}${NC}"
  echo ""

  # Console AWS
  echo -e "${GREEN}🌐 ACESSO AO CONSOLE AWS:${NC}"
  echo "  URL: ${console_url}"
  echo "  Usuários: ${PREFIXO}-aluno01, ${PREFIXO}-aluno02, ..."
  echo "  Senha padrão: Extractta@2026"
  echo ""

  # Chave SSH
  if [ -f "${SCRIPT_DIR}/.ssh-key-info" ]; then
    source "${SCRIPT_DIR}/.ssh-key-info"
    echo -e "${GREEN}🔑 CHAVE SSH:${NC}"
    echo "  📁 Arquivo Local: ${SSH_PRIVATE_KEY}"
    echo "  ⚠️  IMPORTANTE: Guarde este arquivo em local seguro!"
    echo ""
    echo -e "${GREEN}☁️  CHAVE NO S3 (Para Distribuição aos Alunos):${NC}"
    echo "  📦 Bucket: ${S3_BUCKET}"
    echo "  📂 Caminho: ${S3_KEY_PATH}"
    echo ""
    echo -e "${BLUE}🔗 Link para Download (Console AWS):${NC}"
    echo "  ${S3_CONSOLE_URL}"
    echo ""
    echo -e "${YELLOW}📋 Instruções Rápidas para os Alunos:${NC}"
    echo "  1. Acesse o link do S3 acima (precisa estar logado no Console AWS)"
    echo "  2. Clique em 'Download' ou 'Baixar'"
    echo "  3. Salve como: ${SSH_KEY_NAME}.pem"
    echo "  4. Execute: chmod 400 ${SSH_KEY_NAME}.pem"
    echo ""
    echo -e "${YELLOW}📋 Ou via AWS CLI:${NC}"
    echo "  aws s3 cp s3://${S3_BUCKET}/${S3_KEY_PATH} ${SSH_KEY_NAME}.pem"
    echo "  chmod 400 ${SSH_KEY_NAME}.pem"
    echo ""
  else
    echo -e "${GREEN}🔑 CHAVE SSH:${NC}"
    echo "  📁 Arquivo Local: ${SSH_PRIVATE_KEY}"
    echo "  ⚠️  IMPORTANTE: Guarde este arquivo em local seguro!"
    echo ""
  fi

  # Conexão SSH
  echo -e "${GREEN}🔌 CONEXÃO SSH:${NC}"
  echo "  ssh -i ${SSH_PRIVATE_KEY} alunoXX@IP-PUBLICO"
  echo ""

  # IPs dos alunos
  echo -e "  ${BLUE}Acesso dos alunos:${NC}"
  echo ""
  for (( i=1; i<=NUM_ALUNOS; i++ )); do
    local ip
    ip=$(echo "$outputs" | jq -r ".[] | select(.OutputKey==\"EC2Aluno${i}IP\") | .OutputValue" 2>/dev/null || echo "N/A")
    local aluno_name="${PREFIXO}-aluno$(printf '%02d' $i)"
    echo -e "    ${GREEN}Aluno ${i}:${NC} ssh -i ${SSH_PRIVATE_KEY} ${aluno_name}@${ip}"
  done

  echo ""
  echo -e "  ${YELLOW}Gerenciamento:${NC}"
  echo -e "    ./manage-curso.sh status     --stack-name ${STACK_NAME}  — verificar estado"
  echo -e "    ./manage-curso.sh info       --stack-name ${STACK_NAME}  — informações detalhadas"
  echo -e "    ./manage-curso.sh stop       --stack-name ${STACK_NAME}  — parar instâncias"
  echo -e "    ./manage-curso.sh start      --stack-name ${STACK_NAME}  — iniciar instâncias"
  echo -e "    ./manage-curso.sh cleanup    --stack-name ${STACK_NAME}  — remover tudo"
  echo ""
  echo -e "  ${YELLOW}Validação:${NC}"
  echo -e "    ./test-ambiente.sh --stack-name ${STACK_NAME}"
  echo ""
  echo -e "${GREEN}💡 Compartilhe o link do relatório com os alunos!${NC}"
  echo ""

  # Abrir URL no navegador
  if [ -n "${WEBSITE_URL:-}" ]; then
    if command -v open &> /dev/null; then
      open "${WEBSITE_URL}"
    elif command -v xdg-open &> /dev/null; then
      xdg-open "${WEBSITE_URL}"
    fi
  fi
}

# =============================================================================
# Execução principal
# =============================================================================
show_banner
check_prerequisites
interactive_prompts
check_existing_stack
generate_ssh_keys
setup_secrets_manager
setup_s3_bucket
generate_template
confirm_deploy
deploy_stack
generate_html_report
show_summary
