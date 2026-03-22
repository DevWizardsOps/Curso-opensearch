#!/bin/bash
# =============================================================================
# Gerenciador do Ambiente do Curso OpenSearch
# Gerencia TODAS as instâncias EC2 dos alunos de forma centralizada.
# Adaptado do padrão do curso ElastiCache.
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

# =============================================================================
# Ajuda
# =============================================================================
show_help() {
  cat << EOF
🎓 Gerenciador do Curso AWS OpenSearch Service — Módulo 6

Uso: $0 <COMANDO> [OPÇÕES]

COMANDOS:
  status       Mostra status de todas as instâncias EC2 dos alunos
  start        Inicia todas as instâncias EC2 paradas
  stop         Para todas as instâncias EC2 em execução
  restart      Reinicia todas as instâncias EC2
  cleanup      Remove todo o ambiente (S3, SSH key, secret, stack)
  force-clean  Cleanup sem confirmação interativa
  info         Mostra informações detalhadas da stack (outputs, parâmetros, recursos)
  connect ID   Conecta via SSH à instância EC2 do aluno especificado
  logs         Exibe logs das instâncias (system logs via EC2)
  costs        Exibe estimativa de custos dos recursos provisionados

OPÇÕES:
  --stack-name NOME    Nome da stack CloudFormation (padrão: ${DEFAULT_STACK_NAME})
  --profile PERFIL     Perfil AWS a ser usado (opcional)
  -h, --help           Mostra esta ajuda

EXEMPLOS:
  $0 status
  $0 start --stack-name meu-curso-stack
  $0 connect aluno01 --profile producao
  $0 cleanup --stack-name curso-opensearch-stack

EOF
}

# =============================================================================
# Funções auxiliares
# =============================================================================
aws_cmd() {
  aws ${AWS_OPTS} "$@"
}

stack_exists() {
  aws_cmd cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" > /dev/null 2>&1
}

get_instances() {
  aws_cmd cloudformation describe-stack-resources \
    --stack-name "${STACK_NAME}" \
    --query 'StackResources[?ResourceType==`AWS::EC2::Instance`].[LogicalResourceId,PhysicalResourceId]' \
    --output text 2>/dev/null
}

get_instance_ids() {
  local instances_data
  instances_data=$(get_instances)
  if [ -z "$instances_data" ]; then
    echo ""
    return
  fi
  echo "$instances_data" | awk '{print $2}'
}

check_stack() {
  if ! stack_exists; then
    warning "Stack '${STACK_NAME}' não encontrada."
    log "Execute deploy-curso.sh para criar o ambiente."
    exit 0
  fi
}

# =============================================================================
# Comando: status
# =============================================================================
cmd_status() {
  check_stack

  echo -e "${BLUE}📊 Status do Ambiente: ${STACK_NAME}${NC}"
  echo "════════════════════════════════════════════════════════"

  local stack_status
  stack_status=$(aws_cmd cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --query 'Stacks[0].StackStatus' --output text 2>/dev/null)
  echo -e "  Stack Status: ${GREEN}${stack_status}${NC}"
  echo ""

  local instance_ids
  instance_ids=$(get_instance_ids)
  if [ -z "$instance_ids" ]; then
    warning "Nenhuma instância EC2 encontrada na stack."
    return 0
  fi

  echo -e "${BLUE}🖥️  Instâncias EC2:${NC}"
  printf "  %-22s %-12s %-16s %s\n" "INSTÂNCIA" "STATUS" "IP PÚBLICO" "NOME"
  echo "  ────────────────────────────────────────────────────────────────"

  local ids_array=()
  while IFS= read -r id; do
    ids_array+=("$id")
  done <<< "$instance_ids"

  aws_cmd ec2 describe-instances \
    --instance-ids "${ids_array[@]}" \
    --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' \
    --output text 2>/dev/null | while IFS=$'\t' read -r iid state ip name; do
    local color="${GREEN}"
    if [ "$state" = "stopped" ]; then color="${RED}"; fi
    if [ "$state" = "pending" ] || [ "$state" = "stopping" ]; then color="${YELLOW}"; fi
    printf "  %-22s ${color}%-12s${NC} %-16s %s\n" "$iid" "$state" "${ip:-N/A}" "${name:-N/A}"
  done

  echo ""

  # Estimativa de custos
  local num_instances=${#ids_array[@]}
  echo -e "${BLUE}💰 Estimativa de Custos (t3.micro):${NC}"
  echo "  Instâncias: ${num_instances}"
  echo "  ~\$0.0104/hora por instância"
  echo "  ~\$$(echo "${num_instances} * 0.0104 * 24" | bc -l 2>/dev/null | head -c 6 || echo "N/A")/dia total"
  echo ""
}

# =============================================================================
# Comando: start
# =============================================================================
cmd_start() {
  check_stack

  local instance_ids
  instance_ids=$(get_instance_ids)
  if [ -z "$instance_ids" ]; then
    warning "Nenhuma instância encontrada."
    return 0
  fi

  local ids_array=()
  while IFS= read -r id; do ids_array+=("$id"); done <<< "$instance_ids"

  log "Iniciando ${#ids_array[@]} instâncias..."
  aws_cmd ec2 start-instances --instance-ids "${ids_array[@]}" > /dev/null
  success "Comando de start enviado para todas as instâncias."
  log "Aguarde alguns minutos para que fiquem disponíveis."
  echo "Execute '$0 status' para verificar o progresso."
}

# =============================================================================
# Comando: stop
# =============================================================================
cmd_stop() {
  check_stack

  local instance_ids
  instance_ids=$(get_instance_ids)
  if [ -z "$instance_ids" ]; then
    warning "Nenhuma instância encontrada."
    return 0
  fi

  local ids_array=()
  while IFS= read -r id; do ids_array+=("$id"); done <<< "$instance_ids"

  log "Parando ${#ids_array[@]} instâncias..."
  aws_cmd ec2 stop-instances --instance-ids "${ids_array[@]}" > /dev/null
  success "Comando de stop enviado para todas as instâncias."
  echo -e "${BLUE}💰 Custos de EC2 interrompidos (storage continua sendo cobrado).${NC}"
}

# =============================================================================
# Comando: restart
# =============================================================================
cmd_restart() {
  log "Reiniciando instâncias..."
  cmd_stop
  log "Aguardando 30 segundos antes de reiniciar..."
  sleep 30
  cmd_start
}

# =============================================================================
# Comando: cleanup
# =============================================================================
cmd_cleanup() {
  check_stack

  echo -e "${RED}🗑️  ATENÇÃO: Cleanup do ambiente: ${STACK_NAME}${NC}"
  echo -e "${RED}⚠️  ISSO IRÁ DELETAR TODOS OS RECURSOS!${NC}"
  echo ""

  read -rp "Digite 'DELETE' para confirmar a remoção completa: " confirm
  if [ "$confirm" != "DELETE" ]; then
    warning "Cleanup cancelado."
    return 0
  fi

  do_cleanup
}

# =============================================================================
# Comando: force-clean
# =============================================================================
cmd_force_clean() {
  log "Limpeza forçada (sem confirmação)..."
  if ! stack_exists; then
    warning "Stack '${STACK_NAME}' não encontrada. Limpando recursos locais..."
    cleanup_local_files
    return 0
  fi
  do_cleanup
}

do_cleanup() {
  local account_id
  account_id=$(aws_cmd sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
  local region
  region=$(aws_cmd configure get region 2>/dev/null || echo "us-east-1")

  # 1. Deletar stack CloudFormation PRIMEIRO (antes de S3/secrets)
  # A stack referencia o secret via {{resolve:secretsmanager:...}} nos IAM Users.
  # Se deletarmos o secret antes da stack, o CloudFormation falha ao deletar os IAM Users.
  log "Deletando stack CloudFormation: ${STACK_NAME}..."
  aws_cmd cloudformation delete-stack --stack-name "${STACK_NAME}"
  log "Aguardando deleção completa (pode levar alguns minutos)..."

  if aws_cmd cloudformation wait stack-delete-complete --stack-name "${STACK_NAME}" 2>/dev/null; then
    success "Stack deletada com sucesso!"
  else
    error "Falha na deleção da stack. Verifique o console AWS."
    log "Eventos de erro:"
    aws_cmd cloudformation describe-stack-events \
      --stack-name "${STACK_NAME}" \
      --query 'StackEvents[?ResourceStatus==`DELETE_FAILED`].[LogicalResourceId,ResourceStatusReason]' \
      --output table 2>/dev/null || true
    return 1
  fi

  # 2. Esvaziar e remover buckets S3
  log "Esvaziando buckets S3..."
  for bucket_suffix in "labs" "keys" "reports"; do
    local bucket="${STACK_NAME%-stack}-${bucket_suffix}-${account_id}-${region}"
    if aws_cmd s3api head-bucket --bucket "$bucket" 2>/dev/null; then
      log "Esvaziando: ${bucket}"
      aws_cmd s3 rm "s3://${bucket}" --recursive 2>/dev/null || true
      aws_cmd s3 rb "s3://${bucket}" --force 2>/dev/null || true
      success "Bucket removido: ${bucket}"
    fi
  done

  # 3. Deletar chave SSH da AWS
  local key_name="${STACK_NAME%-stack}-key"
  if aws_cmd ec2 describe-key-pairs --key-names "$key_name" 2>/dev/null; then
    log "Deletando chave SSH: ${key_name}"
    aws_cmd ec2 delete-key-pair --key-name "$key_name" 2>/dev/null || true
    success "Chave SSH deletada: ${key_name}"
  fi

  # 4. Deletar secret do Secrets Manager (DEPOIS da stack)
  local secret_name="${STACK_NAME%-stack}-senha"
  if aws_cmd secretsmanager describe-secret --secret-id "$secret_name" 2>/dev/null; then
    log "Deletando secret: ${secret_name}"
    aws_cmd secretsmanager delete-secret \
      --secret-id "$secret_name" \
      --force-delete-without-recovery 2>/dev/null || true
    success "Secret deletado: ${secret_name}"
  fi

  cleanup_local_files
  success "Cleanup concluído! Todos os custos foram interrompidos."
}

cleanup_local_files() {
  log "Limpando arquivos locais..."
  rm -rf "${SCRIPT_DIR}/.ssh-keys"
  rm -f "${SCRIPT_DIR}/template-opensearch.yaml"
  rm -f "${SCRIPT_DIR}/relatorio-acesso.html"
  success "Arquivos locais removidos."
}

# =============================================================================
# Comando: info
# =============================================================================
cmd_info() {
  check_stack

  echo -e "${BLUE}📋 Informações Detalhadas: ${STACK_NAME}${NC}"
  echo "════════════════════════════════════════════════════════"
  echo ""

  echo -e "${BLUE}📊 Outputs da Stack:${NC}"
  aws_cmd cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
    --output table 2>/dev/null || warning "Sem outputs disponíveis."
  echo ""

  echo -e "${BLUE}🏗️  Recursos Criados:${NC}"
  aws_cmd cloudformation describe-stack-resources \
    --stack-name "${STACK_NAME}" \
    --query 'StackResources[*].[ResourceType,LogicalResourceId,ResourceStatus]' \
    --output table 2>/dev/null || warning "Sem recursos disponíveis."
  echo ""

  echo -e "${BLUE}📝 Parâmetros:${NC}"
  aws_cmd cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --query 'Stacks[0].Parameters[*].[ParameterKey,ParameterValue]' \
    --output table 2>/dev/null || warning "Sem parâmetros disponíveis."
}

# =============================================================================
# Comando: connect
# =============================================================================
cmd_connect() {
  local aluno_id="$1"
  if [ -z "$aluno_id" ]; then
    error "Especifique o ID do aluno (ex: aluno01)"
    echo "Uso: $0 connect <ALUNO_ID>"
    exit 1
  fi

  check_stack

  # Buscar IP do aluno nos outputs
  local aluno_num
  aluno_num=$(echo "$aluno_id" | grep -oE '[0-9]+$' || echo "")
  if [ -z "$aluno_num" ]; then
    error "ID do aluno inválido: ${aluno_id}. Use formato: aluno01, aluno02, etc."
    exit 1
  fi

  local ip
  ip=$(aws_cmd cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --query "Stacks[0].Outputs[?OutputKey=='EC2Aluno${aluno_num}IP'].OutputValue" \
    --output text 2>/dev/null)

  if [ -z "$ip" ] || [ "$ip" = "None" ]; then
    error "IP não encontrado para ${aluno_id}."
    return 1
  fi

  local key_file="${SCRIPT_DIR}/.ssh-keys/${STACK_NAME%-stack}-key"
  if [ ! -f "$key_file" ]; then
    error "Chave SSH não encontrada: ${key_file}"
    warning "Baixe a chave do S3 ou execute deploy-curso.sh novamente."
    return 1
  fi

  success "Conectando a ${aluno_id} (${ip})..."
  echo -e "${YELLOW}Use 'exit' para sair da sessão SSH.${NC}"
  echo ""
  ssh -i "$key_file" -o StrictHostKeyChecking=no "${aluno_id}@${ip}"
}

# =============================================================================
# Comando: logs
# =============================================================================
cmd_logs() {
  check_stack

  local instance_ids
  instance_ids=$(get_instance_ids)
  if [ -z "$instance_ids" ]; then
    warning "Nenhuma instância encontrada."
    return 0
  fi

  echo -e "${BLUE}📜 Logs das Instâncias:${NC}"
  echo ""

  while IFS= read -r iid; do
    echo -e "${BLUE}--- ${iid} ---${NC}"
    aws_cmd ec2 get-console-output \
      --instance-id "$iid" \
      --query 'Output' --output text 2>/dev/null | tail -20 || warning "Sem logs para ${iid}"
    echo ""
  done <<< "$instance_ids"
}

# =============================================================================
# Comando: costs
# =============================================================================
cmd_costs() {
  check_stack

  local instance_ids
  instance_ids=$(get_instance_ids)
  local num_instances=0
  if [ -n "$instance_ids" ]; then
    num_instances=$(echo "$instance_ids" | wc -l | tr -d ' ')
  fi

  echo -e "${BLUE}💰 Estimativa de Custos — ${STACK_NAME}${NC}"
  echo "════════════════════════════════════════════════════════"
  echo ""
  echo "  Recurso                    Custo/hora    Custo/dia"
  echo "  ─────────────────────────  ──────────    ─────────"
  printf "  EC2 t3.micro (x%d)          \$%.4f       \$%.2f\n" \
    "$num_instances" \
    "$(echo "$num_instances * 0.0104" | bc -l 2>/dev/null || echo "0")" \
    "$(echo "$num_instances * 0.0104 * 24" | bc -l 2>/dev/null || echo "0")"
  echo "  NAT Gateway                 \$0.0450       \$1.08"
  echo "  EBS (10GB gp3 x${num_instances})          ~\$0.0033       ~\$0.08"
  echo "  ─────────────────────────  ──────────    ─────────"
  printf "  TOTAL ESTIMADO              ~\$%.4f      ~\$%.2f\n" \
    "$(echo "$num_instances * 0.0104 + 0.045 + $num_instances * 0.0033" | bc -l 2>/dev/null || echo "0")" \
    "$(echo "($num_instances * 0.0104 + 0.045 + $num_instances * 0.0033) * 24" | bc -l 2>/dev/null || echo "0")"
  echo ""
  echo -e "  ${YELLOW}Nota: OpenSearch Domain (criado pelo aluno) não está incluído.${NC}"
  echo -e "  ${YELLOW}t3.small.search: ~\$0.036/hora (~\$0.86/dia) por aluno.${NC}"
  echo ""
}

# =============================================================================
# Parse de argumentos
# =============================================================================
STACK_NAME="${DEFAULT_STACK_NAME}"
COMMAND=""
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --stack-name) STACK_NAME="$2"; shift 2 ;;
    --profile)    AWS_PROFILE="$2"; AWS_OPTS="--profile ${2}"; shift 2 ;;
    -h|--help)    show_help; exit 0 ;;
    status|start|stop|restart|cleanup|force-clean|info|connect|logs|costs)
      COMMAND="$1"; shift ;;
    *) EXTRA_ARGS+=("$1"); shift ;;
  esac
done

if [ -z "$COMMAND" ]; then
  error "Comando não especificado."
  echo ""
  show_help
  exit 1
fi

# Verificar AWS CLI
if ! aws_cmd sts get-caller-identity > /dev/null 2>&1; then
  error "AWS CLI não configurado ou sem permissões."
  if [ -n "$AWS_PROFILE" ]; then
    error "Verifique se o perfil '${AWS_PROFILE}' está configurado."
  else
    error "Execute: aws configure"
  fi
  exit 1
fi

# Executar comando
case $COMMAND in
  status)      cmd_status ;;
  start)       cmd_start ;;
  stop)        cmd_stop ;;
  restart)     cmd_restart ;;
  cleanup)     cmd_cleanup ;;
  force-clean) cmd_force_clean ;;
  info)        cmd_info ;;
  connect)     cmd_connect "${EXTRA_ARGS[0]}" ;;
  logs)        cmd_logs ;;
  costs)       cmd_costs ;;
  *)           error "Comando desconhecido: ${COMMAND}"; show_help; exit 1 ;;
esac
