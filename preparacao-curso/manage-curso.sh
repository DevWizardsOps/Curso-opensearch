#!/bin/bash
set -e

# =============================================================================
# Preparação do Curso — Gerenciamento do Ambiente
# Comandos: status, start, stop, restart, cleanup, force-clean, info, connect,
#           logs, costs
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

STACK_NAME="curso-opensearch-modulo6"
PROFILE=""
REGION=""

# Parse de argumentos
COMMAND="${1:-}"
shift || true

while [[ $# -gt 0 ]]; do
  case $1 in
    --profile) PROFILE="$2"; shift 2 ;;
    --region)  REGION="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Monta opções do AWS CLI
AWS_OPTS=""
if [ -n "$PROFILE" ]; then
  AWS_OPTS="--profile ${PROFILE}"
fi
if [ -n "$REGION" ]; then
  AWS_OPTS="${AWS_OPTS} --region ${REGION}"
fi

show_usage() {
  echo ""
  echo "Uso: $0 <comando> [--profile PROFILE] [--region REGION]"
  echo ""
  echo "Comandos disponíveis:"
  echo "  status       Exibe estado atual do ambiente"
  echo "  start        Inicia instâncias EC2 paradas"
  echo "  stop         Para instâncias EC2"
  echo "  restart      Reinicia instâncias EC2"
  echo "  cleanup      Remove stack CloudFormation (com confirmação)"
  echo "  force-clean  Remove stack sem confirmação"
  echo "  info         Exibe informações detalhadas do ambiente"
  echo "  connect      Gera comando SSH para túnel ao Dashboards"
  echo "  logs         Exibe eventos recentes da stack"
  echo "  costs        Estima custo acumulado"
  echo ""
}

# Obtém output da stack
get_stack_output() {
  local key="$1"
  aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    ${AWS_OPTS} \
    --query "Stacks[0].Outputs[?OutputKey=='${key}'].OutputValue" \
    --output text 2>/dev/null || echo "N/A"
}

# Obtém ID da instância bastion
get_bastion_instance_id() {
  aws ec2 describe-instances \
    ${AWS_OPTS} \
    --filters "Name=tag:Name,Values=curso-opensearch-bastion" "Name=instance-state-name,Values=running,stopped" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text 2>/dev/null || echo "N/A"
}

# ============================================================
# Comandos
# ============================================================

cmd_status() {
  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}  Status do Ambiente                     ${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""

  # Stack status
  local stack_status
  stack_status=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    ${AWS_OPTS} \
    --query 'Stacks[0].StackStatus' \
    --output text 2>/dev/null) || {
    error "Stack '${STACK_NAME}' não encontrada."
    exit 1
  }

  case "$stack_status" in
    CREATE_COMPLETE|UPDATE_COMPLETE)
      echo -e "  Stack: ${GREEN}${stack_status}${NC}" ;;
    *PROGRESS*)
      echo -e "  Stack: ${YELLOW}${stack_status}${NC}" ;;
    *FAILED*|*ROLLBACK*)
      echo -e "  Stack: ${RED}${stack_status}${NC}" ;;
    *)
      echo -e "  Stack: ${stack_status}" ;;
  esac

  # Bastion status
  local instance_id
  instance_id=$(get_bastion_instance_id)
  if [ "$instance_id" != "N/A" ] && [ "$instance_id" != "None" ]; then
    local instance_state
    instance_state=$(aws ec2 describe-instances \
      ${AWS_OPTS} \
      --instance-ids "${instance_id}" \
      --query 'Reservations[0].Instances[0].State.Name' \
      --output text 2>/dev/null || echo "unknown")
    echo -e "  Bastion EC2: ${instance_state} (${instance_id})"
  else
    echo -e "  Bastion EC2: ${YELLOW}não encontrado${NC}"
  fi

  # OpenSearch endpoint
  local endpoint
  endpoint=$(get_stack_output "OpenSearchEndpoint")
  echo -e "  OpenSearch: ${endpoint}"
  echo ""
}

cmd_start() {
  echo ""
  log "Iniciando instâncias EC2..."
  local instance_id
  instance_id=$(get_bastion_instance_id)
  if [ "$instance_id" = "N/A" ] || [ "$instance_id" = "None" ]; then
    error "Instância bastion não encontrada."
    exit 1
  fi
  aws ec2 start-instances --instance-ids "${instance_id}" ${AWS_OPTS} > /dev/null
  success "Instância ${instance_id} iniciando..."
  log "Aguarde alguns minutos para a instância ficar disponível."
  echo ""
}

cmd_stop() {
  echo ""
  log "Parando instâncias EC2..."
  warning "O domínio OpenSearch não pode ser parado (apenas deletado)."
  local instance_id
  instance_id=$(get_bastion_instance_id)
  if [ "$instance_id" = "N/A" ] || [ "$instance_id" = "None" ]; then
    error "Instância bastion não encontrada."
    exit 1
  fi
  aws ec2 stop-instances --instance-ids "${instance_id}" ${AWS_OPTS} > /dev/null
  success "Instância ${instance_id} parando..."
  echo ""
}

cmd_restart() {
  echo ""
  log "Reiniciando instâncias EC2..."
  local instance_id
  instance_id=$(get_bastion_instance_id)
  if [ "$instance_id" = "N/A" ] || [ "$instance_id" = "None" ]; then
    error "Instância bastion não encontrada."
    exit 1
  fi
  aws ec2 reboot-instances --instance-ids "${instance_id}" ${AWS_OPTS} > /dev/null
  success "Instância ${instance_id} reiniciando..."
  echo ""
}

cmd_cleanup() {
  echo ""
  echo -e "${RED}========================================${NC}"
  echo -e "${RED}  Remover Ambiente                       ${NC}"
  echo -e "${RED}========================================${NC}"
  echo ""
  warning "Isso irá DELETAR toda a infraestrutura do curso:"
  echo "  • Domínio OpenSearch"
  echo "  • EC2 Bastion"
  echo "  • VPC, Subnets, Security Groups"
  echo "  • IAM Roles e Policies"
  echo ""
  read -rp "Tem certeza? Digite 'sim' para confirmar: " confirm
  if [ "$confirm" != "sim" ]; then
    log "Operação cancelada."
    exit 0
  fi
  echo ""
  do_cleanup
}

cmd_force_clean() {
  echo ""
  warning "Removendo stack '${STACK_NAME}' sem confirmação..."
  do_cleanup
}

do_cleanup() {
  log "Deletando stack '${STACK_NAME}'..."
  aws cloudformation delete-stack \
    --stack-name "${STACK_NAME}" \
    ${AWS_OPTS} || {
    error "Falha ao deletar stack."
    exit 1
  }
  log "Aguardando exclusão da stack (pode levar 10-20 minutos)..."
  aws cloudformation wait stack-delete-complete \
    --stack-name "${STACK_NAME}" \
    ${AWS_OPTS} 2>/dev/null || {
    warning "Timeout aguardando exclusão. Verifique o console AWS."
    exit 1
  }
  success "Stack '${STACK_NAME}' removida com sucesso."
  echo ""
}

cmd_info() {
  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}  Informações do Ambiente                ${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""

  local endpoint bastion_ip dashboards_url domain_arn
  endpoint=$(get_stack_output "OpenSearchEndpoint")
  bastion_ip=$(get_stack_output "BastionPublicIP")
  dashboards_url=$(get_stack_output "OpenSearchDashboardsURL")
  domain_arn=$(get_stack_output "OpenSearchDomainArn")

  echo -e "  ${BLUE}Stack:${NC}              ${STACK_NAME}"
  echo -e "  ${BLUE}OpenSearch Endpoint:${NC} ${endpoint}"
  echo -e "  ${BLUE}Dashboards URL:${NC}     ${dashboards_url}"
  echo -e "  ${BLUE}Domain ARN:${NC}         ${domain_arn}"
  echo -e "  ${BLUE}Bastion IP:${NC}         ${bastion_ip}"
  echo ""
  echo -e "  ${YELLOW}Acesso SSH:${NC}"
  echo -e "    ssh -i <sua-chave.pem> ec2-user@${bastion_ip}"
  echo ""
  echo -e "  ${YELLOW}Túnel para Dashboards:${NC}"
  echo -e "    ssh -i <sua-chave.pem> -L 5601:${endpoint#https://}:5601 ec2-user@${bastion_ip}"
  echo ""
}

cmd_connect() {
  echo ""
  local endpoint bastion_ip
  endpoint=$(get_stack_output "OpenSearchEndpoint")
  bastion_ip=$(get_stack_output "BastionPublicIP")

  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}  Comandos de Conexão                    ${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""
  echo -e "  ${YELLOW}SSH direto ao bastion:${NC}"
  echo -e "    ssh -i <sua-chave.pem> ec2-user@${bastion_ip}"
  echo ""
  echo -e "  ${YELLOW}Túnel SSH para OpenSearch Dashboards:${NC}"
  echo -e "    ssh -i <sua-chave.pem> -L 5601:${endpoint#https://}:5601 ec2-user@${bastion_ip}"
  echo ""
  echo -e "  Após o túnel, acesse: ${GREEN}http://localhost:5601${NC}"
  echo ""
}

cmd_logs() {
  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}  Eventos Recentes da Stack              ${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""

  aws cloudformation describe-stack-events \
    --stack-name "${STACK_NAME}" \
    ${AWS_OPTS} \
    --query 'StackEvents[:15].[Timestamp,ResourceStatus,ResourceType,LogicalResourceId]' \
    --output table 2>/dev/null || {
    error "Não foi possível obter eventos da stack."
    exit 1
  }
  echo ""
}

cmd_costs() {
  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}  Estimativa de Custos                   ${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""

  local start_date end_date
  start_date=$(date -u -v-7d '+%Y-%m-%d' 2>/dev/null || date -u -d '7 days ago' '+%Y-%m-%d' 2>/dev/null || echo "")
  end_date=$(date -u '+%Y-%m-%d')

  if [ -z "$start_date" ]; then
    warning "Não foi possível calcular a data de início."
    start_date="2024-01-01"
  fi

  log "Período: ${start_date} a ${end_date}"
  echo ""

  aws ce get-cost-and-usage \
    --time-period "Start=${start_date},End=${end_date}" \
    --granularity DAILY \
    --metrics "UnblendedCost" \
    --filter "{\"Tags\":{\"Key\":\"Projeto\",\"Values\":[\"Curso-OpenSearch-Modulo6\"]}}" \
    ${AWS_OPTS} \
    --query 'ResultsByTime[].[TimePeriod.Start,Total.UnblendedCost.Amount]' \
    --output table 2>/dev/null || {
    warning "Não foi possível obter dados de custo."
    warning "Verifique se o Cost Explorer está habilitado na conta."
    echo ""
    echo -e "  ${YELLOW}Estimativa manual:${NC}"
    echo -e "    OpenSearch t3.small.search : ~\$0.036/hora (~\$0.86/dia)"
    echo -e "    EC2 t3.micro               : ~\$0.0104/hora (~\$0.25/dia)"
    echo -e "    EBS 10GB gp3               : ~\$0.08/dia"
    echo -e "    ${GREEN}Total estimado: ~\$1.19/dia${NC}"
  }
  echo ""
}

# =============================================================================
# Execução principal
# =============================================================================

if [ -z "$COMMAND" ]; then
  show_usage
  exit 1
fi

case "$COMMAND" in
  status)      cmd_status ;;
  start)       cmd_start ;;
  stop)        cmd_stop ;;
  restart)     cmd_restart ;;
  cleanup)     cmd_cleanup ;;
  force-clean) cmd_force_clean ;;
  info)        cmd_info ;;
  connect)     cmd_connect ;;
  logs)        cmd_logs ;;
  costs)       cmd_costs ;;
  help|--help|-h) show_usage ;;
  *)
    error "Comando desconhecido: ${COMMAND}"
    show_usage
    exit 1
    ;;
esac
