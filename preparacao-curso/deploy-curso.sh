#!/bin/bash
set -e

# =============================================================================
# Preparação do Curso — Deploy do Ambiente
# Provisiona toda a infraestrutura AWS via CloudFormation
# =============================================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log()     { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warning() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
error()   { echo -e "${RED}[ERRO]${NC} $1" >&2; }

# Valores padrão
PROFILE=""
REGION="us-east-1"
ALUNOS=1
DRY_RUN=false
STACK_NAME="curso-opensearch-modulo6"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="${SCRIPT_DIR}/template-opensearch.yaml"

# Banner
show_banner() {
  echo ""
  echo -e "${CYAN}  ╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}  ║                                                  ║${NC}"
  echo -e "${CYAN}  ║   ${GREEN}AWS OpenSearch Service${CYAN}                        ║${NC}"
  echo -e "${CYAN}  ║   ${GREEN}Módulo 6 — Labs e Troubleshooting${CYAN}             ║${NC}"
  echo -e "${CYAN}  ║                                                  ║${NC}"
  echo -e "${CYAN}  ║   ${BLUE}Deploy do Ambiente de Laboratório${CYAN}              ║${NC}"
  echo -e "${CYAN}  ║                                                  ║${NC}"
  echo -e "${CYAN}  ╚══════════════════════════════════════════════════╝${NC}"
  echo ""
}

# Parse de argumentos
while [[ $# -gt 0 ]]; do
  case $1 in
    --profile)  PROFILE="$2"; shift 2 ;;
    --region)   REGION="$2"; shift 2 ;;
    --alunos)   ALUNOS="$2"; shift 2 ;;
    --dry-run)  DRY_RUN=true; shift ;;
    --help|-h)
      echo "Uso: $0 [--profile PROFILE] [--region REGION] [--alunos N] [--dry-run]"
      echo ""
      echo "Opções:"
      echo "  --profile PROFILE   AWS CLI profile (padrão: default)"
      echo "  --region REGION     Região AWS (padrão: us-east-1)"
      echo "  --alunos N          Número de alunos (padrão: 1)"
      echo "  --dry-run           Apenas gera o template, não faz deploy"
      exit 0
      ;;
    *) error "Argumento desconhecido: $1"; exit 1 ;;
  esac
done

# Monta opções do AWS CLI
AWS_OPTS=""
if [ -n "$PROFILE" ]; then
  AWS_OPTS="--profile ${PROFILE}"
fi
AWS_OPTS="${AWS_OPTS} --region ${REGION}"

# Verifica pré-requisitos
check_prerequisites() {
  log "Verificando pré-requisitos..."
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
    success "curl encontrado."
  fi

  # Credenciais AWS
  log "Verificando credenciais AWS..."
  local identity
  identity=$(aws sts get-caller-identity ${AWS_OPTS} 2>&1) || {
    error "Credenciais AWS inválidas ou não configuradas."
    error "Detalhes: ${identity}"
    error "Configure com: aws configure ${PROFILE:+--profile ${PROFILE}}"
    missing=1
  }

  if [ "$missing" -eq 1 ]; then
    echo ""
    error "Pré-requisitos não atendidos. Corrija os erros acima e tente novamente."
    exit 1
  fi

  local account_id
  account_id=$(echo "$identity" | jq -r '.Account')
  success "Credenciais válidas — Conta: ${account_id}"
  echo ""
}

# Verifica se a stack já existe
check_existing_stack() {
  log "Verificando se a stack '${STACK_NAME}' já existe..."
  local stack_status
  stack_status=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    ${AWS_OPTS} \
    --query 'Stacks[0].StackStatus' \
    --output text 2>/dev/null) || {
    log "Stack não encontrada. Prosseguindo com a criação."
    return 1
  }

  if [ -n "$stack_status" ] && [ "$stack_status" != "None" ]; then
    warning "Stack '${STACK_NAME}' já existe com status: ${stack_status}"
    echo ""
    echo -e "  Use ${BLUE}./manage-curso.sh status${NC} para verificar o estado atual."
    echo -e "  Use ${BLUE}./manage-curso.sh cleanup${NC} para remover e recriar."
    echo ""
    exit 0
  fi
  return 1
}

# Gera o template CloudFormation
generate_template() {
  log "Gerando template CloudFormation..."
  bash "${SCRIPT_DIR}/gerar-template.sh" --alunos "${ALUNOS}" --output "${TEMPLATE_FILE}"

  if [ ! -f "${TEMPLATE_FILE}" ]; then
    error "Falha ao gerar template. Arquivo não encontrado: ${TEMPLATE_FILE}"
    exit 1
  fi
  success "Template gerado: ${TEMPLATE_FILE}"
  echo ""
}

# Solicita parâmetros ao usuário
get_parameters() {
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}  Parâmetros do Deploy                   ${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""

  # Key Pair
  if [ -z "$KEY_PAIR" ]; then
    log "Key Pairs disponíveis na região ${REGION}:"
    aws ec2 describe-key-pairs ${AWS_OPTS} \
      --query 'KeyPairs[].KeyName' \
      --output table 2>/dev/null || warning "Não foi possível listar Key Pairs."
    echo ""
    read -rp "Nome do Key Pair para SSH: " KEY_PAIR
    if [ -z "$KEY_PAIR" ]; then
      error "Key Pair é obrigatório."
      exit 1
    fi
  fi

  # Senha do OpenSearch
  if [ -z "$MASTER_PASSWORD" ]; then
    echo ""
    echo -e "${YELLOW}A senha deve conter: maiúscula, minúscula, número e caractere especial.${NC}"
    read -rsp "Senha master do OpenSearch: " MASTER_PASSWORD
    echo ""
    if [ ${#MASTER_PASSWORD} -lt 8 ]; then
      error "Senha deve ter no mínimo 8 caracteres."
      exit 1
    fi
  fi
  echo ""
}

# Executa o deploy
deploy_stack() {
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}  Executando Deploy                      ${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""

  log "Stack: ${STACK_NAME}"
  log "Região: ${REGION}"
  log "Template: ${TEMPLATE_FILE}"
  log "Key Pair: ${KEY_PAIR}"
  log "Alunos: ${ALUNOS}"
  echo ""

  if [ "$DRY_RUN" = true ]; then
    warning "Modo --dry-run ativado. Template gerado mas deploy não executado."
    log "Template disponível em: ${TEMPLATE_FILE}"
    echo ""
    log "Para validar o template:"
    echo "  aws cloudformation validate-template --template-body file://${TEMPLATE_FILE} ${AWS_OPTS}"
    echo ""
    return 0
  fi

  log "Validando template..."
  aws cloudformation validate-template \
    --template-body "file://${TEMPLATE_FILE}" \
    ${AWS_OPTS} > /dev/null 2>&1 || {
    error "Template inválido. Verifique o arquivo: ${TEMPLATE_FILE}"
    exit 1
  }
  success "Template válido."
  echo ""

  log "Iniciando deploy via CloudFormation..."
  log "Isso pode levar de 15 a 25 minutos (OpenSearch Domain demora para provisionar)."
  echo ""

  aws cloudformation deploy \
    --template-file "${TEMPLATE_FILE}" \
    --stack-name "${STACK_NAME}" \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides \
      "MasterUser=admin" \
      "MasterPassword=${MASTER_PASSWORD}" \
      "KeyPairName=${KEY_PAIR}" \
    ${AWS_OPTS} || {
    error "Falha no deploy da stack '${STACK_NAME}'."
    error "Verifique os eventos com: aws cloudformation describe-stack-events --stack-name ${STACK_NAME} ${AWS_OPTS}"
    exit 1
  }

  success "Deploy concluído com sucesso!"
  echo ""
}

# Exibe informações pós-deploy
show_post_deploy_info() {
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}  Deploy Concluído!                      ${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo ""

  # Obtém outputs da stack
  local outputs
  outputs=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    ${AWS_OPTS} \
    --query 'Stacks[0].Outputs' \
    --output json 2>/dev/null) || {
    warning "Não foi possível obter outputs da stack."
    return 0
  }

  local endpoint bastion_ip dashboards_url
  endpoint=$(echo "$outputs" | jq -r '.[] | select(.OutputKey=="OpenSearchEndpoint") | .OutputValue' 2>/dev/null || echo "N/A")
  bastion_ip=$(echo "$outputs" | jq -r '.[] | select(.OutputKey=="BastionPublicIP") | .OutputValue' 2>/dev/null || echo "N/A")
  dashboards_url=$(echo "$outputs" | jq -r '.[] | select(.OutputKey=="OpenSearchDashboardsURL") | .OutputValue' 2>/dev/null || echo "N/A")

  echo -e "  ${BLUE}OpenSearch Endpoint:${NC}  ${endpoint}"
  echo -e "  ${BLUE}Dashboards URL:${NC}       ${dashboards_url}"
  echo -e "  ${BLUE}Bastion IP:${NC}           ${bastion_ip}"
  echo -e "  ${BLUE}Usuário:${NC}              admin"
  echo ""
  echo -e "  ${YELLOW}Próximos passos:${NC}"
  echo -e "    1. Acesse o bastion: ssh -i <sua-chave.pem> ec2-user@${bastion_ip}"
  echo -e "    2. Execute: ./setup-aluno.sh --endpoint ${endpoint} --user admin --pass <senha>"
  echo -e "    3. Valide: ./test-ambiente.sh"
  echo ""
  echo -e "  ${YELLOW}Gerenciamento:${NC}"
  echo -e "    ./manage-curso.sh status    — verificar estado"
  echo -e "    ./manage-curso.sh info      — informações detalhadas"
  echo -e "    ./manage-curso.sh cleanup   — remover ambiente"
  echo ""
}

# =============================================================================
# Execução principal
# =============================================================================

show_banner
check_prerequisites
check_existing_stack || true
generate_template
get_parameters
deploy_stack

if [ "$DRY_RUN" = false ]; then
  show_post_deploy_info
fi
