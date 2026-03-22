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
  echo -e "${YELLOW}A senha será usada para login no console AWS dos alunos.${NC}"
  echo -e "${YELLOW}Requisitos: mínimo 8 caracteres, maiúscula, minúscula, número e especial.${NC}"
  while true; do
    read -rsp "$(echo -e "${BLUE}[?]${NC} Senha do console AWS: ")" CONSOLE_PASSWORD
    echo ""
    if [ ${#CONSOLE_PASSWORD} -lt 8 ]; then
      warning "Senha deve ter no mínimo 8 caracteres. Tente novamente."
      continue
    fi
    read -rsp "$(echo -e "${BLUE}[?]${NC} Confirme a senha: ")" CONSOLE_PASSWORD_CONFIRM
    echo ""
    if [ "$CONSOLE_PASSWORD" != "$CONSOLE_PASSWORD_CONFIRM" ]; then
      warning "Senhas não conferem. Tente novamente."
      continue
    fi
    break
  done
  success "Senha configurada"
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
  aws s3 cp "${SSH_PRIVATE_KEY}" "s3://${S3_BUCKET}/keys/${SSH_KEY_NAME}.pem" \
    ${AWS_OPTS} --region "${REGION}" > /dev/null
  success "Chave SSH enviada para: s3://${S3_BUCKET}/keys/${SSH_KEY_NAME}.pem"

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

  # Início do HTML
  cat > "${HTML_REPORT}" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Curso OpenSearch — Relatório de Acesso</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #f0f2f5;
      color: #333;
      padding: 20px;
    }
    .header {
      background: linear-gradient(135deg, #1a73e8, #0d47a1);
      color: white;
      padding: 30px;
      border-radius: 12px;
      margin-bottom: 30px;
      text-align: center;
    }
    .header h1 { font-size: 28px; margin-bottom: 8px; }
    .header p { font-size: 16px; opacity: 0.9; }
    .info-bar {
      background: white;
      padding: 20px;
      border-radius: 8px;
      margin-bottom: 20px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      display: flex;
      flex-wrap: wrap;
      gap: 20px;
    }
    .info-item { flex: 1; min-width: 200px; }
    .info-item label { font-size: 12px; color: #666; text-transform: uppercase; }
    .info-item span { display: block; font-size: 14px; font-weight: 600; margin-top: 4px; }
    .cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(380px, 1fr)); gap: 20px; }
    .card {
      background: white;
      border-radius: 8px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      overflow: hidden;
    }
    .card-header {
      background: #1a73e8;
      color: white;
      padding: 15px 20px;
      font-size: 18px;
      font-weight: 600;
    }
    .card-body { padding: 20px; }
    .card-body .field { margin-bottom: 12px; }
    .card-body .field label {
      font-size: 12px;
      color: #666;
      text-transform: uppercase;
      display: block;
      margin-bottom: 2px;
    }
    .card-body .field .value {
      font-family: 'Courier New', monospace;
      font-size: 13px;
      background: #f5f5f5;
      padding: 8px 12px;
      border-radius: 4px;
      word-break: break-all;
    }
    .card-body .ssh-cmd {
      background: #263238;
      color: #80cbc4;
      padding: 10px 14px;
      border-radius: 4px;
      font-family: 'Courier New', monospace;
      font-size: 13px;
      margin-top: 8px;
    }
    .note {
      background: #fff3cd;
      border: 1px solid #ffc107;
      padding: 15px 20px;
      border-radius: 8px;
      margin-top: 20px;
      font-size: 14px;
    }
    .note strong { color: #856404; }
    .footer {
      text-align: center;
      margin-top: 30px;
      color: #999;
      font-size: 12px;
    }
  </style>
</head>
<body>
  <div class="header">
    <h1>🔍 Curso AWS OpenSearch Service — Módulo 6</h1>
    <p>Relatório de Acesso dos Alunos</p>
  </div>
HTMLEOF

  # Info bar
  cat >> "${HTML_REPORT}" << HTMLEOF
  <div class="info-bar">
    <div class="info-item">
      <label>Console AWS</label>
      <span><a href="${console_url}" target="_blank">${console_url}</a></span>
    </div>
    <div class="info-item">
      <label>Região</label>
      <span>${REGION}</span>
    </div>
    <div class="info-item">
      <label>Stack</label>
      <span>${STACK_NAME}</span>
    </div>
    <div class="info-item">
      <label>Alunos</label>
      <span>${NUM_ALUNOS}</span>
    </div>
    <div class="info-item">
      <label>S3 Bucket</label>
      <span>${S3_BUCKET}</span>
    </div>
  </div>

  <div class="note">
    <strong>⚠️ Importante:</strong> A senha do console AWS está armazenada no AWS Secrets Manager
    (secret: <code>${SECRET_NAME}</code>). Cada aluno deve criar seu próprio OpenSearch Domain no Lab 0.
  </div>

  <br>
  <div class="cards">
HTMLEOF

  # Card por aluno
  for (( i=1; i<=NUM_ALUNOS; i++ )); do
    local ip access_key secret_key
    ip=$(echo "$outputs" | jq -r ".[] | select(.OutputKey==\"EC2Aluno${i}IP\") | .OutputValue" 2>/dev/null || echo "N/A")
    access_key=$(echo "$outputs" | jq -r ".[] | select(.OutputKey==\"AccessKeyAluno${i}Output\") | .OutputValue" 2>/dev/null || echo "N/A")
    secret_key=$(echo "$outputs" | jq -r ".[] | select(.OutputKey==\"SecretKeyAluno${i}\") | .OutputValue" 2>/dev/null || echo "N/A")
    local username="${PREFIXO}-aluno${i}"

    cat >> "${HTML_REPORT}" << HTMLEOF
    <div class="card">
      <div class="card-header">👤 Aluno ${i} — ${username}</div>
      <div class="card-body">
        <div class="field">
          <label>IP da Instância EC2</label>
          <div class="value">${ip}</div>
        </div>
        <div class="field">
          <label>Usuário IAM</label>
          <div class="value">${username}</div>
        </div>
        <div class="field">
          <label>Access Key</label>
          <div class="value">${access_key}</div>
        </div>
        <div class="field">
          <label>Secret Key</label>
          <div class="value">${secret_key}</div>
        </div>
        <div class="field">
          <label>Comando SSH</label>
          <div class="ssh-cmd">ssh -i ${SSH_KEY_NAME}.pem ec2-user@${ip}</div>
        </div>
        <div class="field">
          <label>Console AWS</label>
          <div class="value"><a href="${console_url}" target="_blank">${console_url}</a></div>
        </div>
      </div>
    </div>
HTMLEOF
  done

  # Fechar HTML
  cat >> "${HTML_REPORT}" << HTMLEOF
  </div>

  <div class="note">
    <strong>📋 Instruções para os alunos:</strong><br>
    1. Acesse a EC2 via SSH usando o comando indicado no card acima<br>
    2. Navegue até <code>cd ~/Curso-opensearch/modulo6-lab/lab0-setup/</code><br>
    3. Siga o README.md do Lab 0 para criar seu OpenSearch Domain<br>
    4. Configure as variáveis de ambiente com <code>./configurar-ambiente.sh</code><br>
    5. Valide a conexão com <code>./testar-conexao.sh</code><br>
    6. Inicie os labs a partir do Lab 1
  </div>

  <div class="footer">
    Gerado em $(date +'%Y-%m-%d %H:%M:%S') — Curso AWS OpenSearch Service — Módulo 6
  </div>
</body>
</html>
HTMLEOF

  success "Relatório HTML gerado: ${HTML_REPORT}"

  # Upload do relatório para S3
  log "Fazendo upload do relatório para S3..."
  aws s3 cp "${HTML_REPORT}" "s3://${S3_BUCKET}/relatorio-acesso.html" \
    --content-type "text/html" \
    ${AWS_OPTS} --region "${REGION}" > /dev/null
  success "Relatório disponível em: s3://${S3_BUCKET}/relatorio-acesso.html"
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
  echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}  ✅ Deploy Concluído com Sucesso!${NC}"
  echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "  ${BLUE}Console AWS:${NC}     ${console_url}"
  echo -e "  ${BLUE}Região:${NC}          ${REGION}"
  echo -e "  ${BLUE}Stack:${NC}           ${STACK_NAME}"
  echo -e "  ${BLUE}S3 Bucket:${NC}       s3://${S3_BUCKET}"
  echo -e "  ${BLUE}Secret:${NC}          ${SECRET_NAME}"
  echo -e "  ${BLUE}SSH Key:${NC}         ${SSH_PRIVATE_KEY}"
  echo -e "  ${BLUE}Relatório:${NC}       ${HTML_REPORT}"
  echo ""

  echo -e "  ${BLUE}Acesso dos alunos:${NC}"
  echo ""
  for (( i=1; i<=NUM_ALUNOS; i++ )); do
    local ip
    ip=$(echo "$outputs" | jq -r ".[] | select(.OutputKey==\"EC2Aluno${i}IP\") | .OutputValue" 2>/dev/null || echo "N/A")
    echo -e "    ${GREEN}Aluno ${i}:${NC} ssh -i ${SSH_PRIVATE_KEY} ec2-user@${ip}"
  done

  echo ""
  echo -e "  ${YELLOW}Próximos passos:${NC}"
  echo -e "    1. Distribua a chave SSH (${SSH_PRIVATE_KEY}) para os alunos"
  echo -e "    2. Compartilhe o relatório HTML com as credenciais"
  echo -e "    3. Cada aluno acessa sua EC2 via SSH"
  echo -e "    4. Cada aluno cria seu OpenSearch Domain no Lab 0"
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
