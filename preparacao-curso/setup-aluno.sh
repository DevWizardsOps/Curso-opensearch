#!/bin/bash
# =============================================================================
# Setup do Aluno — Configuração Automática da EC2 via UserData
# Este script é baixado do S3 e executado automaticamente no boot da instância.
# Adaptado do padrão do curso ElastiCache.
#
# NÃO configura OPENSEARCH_ENDPOINT, OPENSEARCH_USER ou OPENSEARCH_PASS.
# O aluno configura essas variáveis no Lab 0 após criar seu OpenSearch Domain.
# =============================================================================

set -e

# Parâmetros recebidos via UserData
ALUNO_ID=$1
AWS_REGION=$2
ACCESS_KEY=$3
SECRET_KEY=$4

LOG_FILE="/var/log/setup-aluno.log"

# Função de log
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

log "Iniciando setup para ${ALUNO_ID} na região ${AWS_REGION}"

# =============================================================================
# Instalar ferramentas
# =============================================================================
install_tool() {
  local tool="$1"
  log "Instalando ${tool}..."
  if ! yum install -y "${tool}" >> "${LOG_FILE}" 2>&1; then
    log "[WARN] Falha ao instalar ${tool}. Continuando..."
  fi
}

log "Atualizando pacotes..."
yum update -y >> "${LOG_FILE}" 2>&1 || log "[WARN] Falha no yum update. Continuando..."

install_tool "curl"
install_tool "jq"
install_tool "git"
install_tool "aws-cli"

# =============================================================================
# Criar usuário Linux para o aluno
# =============================================================================
log "Criando usuário ${ALUNO_ID}..."
useradd -m -s /bin/bash "${ALUNO_ID}"
echo "${ALUNO_ID} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Copiar chave SSH do ec2-user para o aluno
mkdir -p "/home/${ALUNO_ID}/.ssh"
cp /home/ec2-user/.ssh/authorized_keys "/home/${ALUNO_ID}/.ssh/authorized_keys"
chown -R "${ALUNO_ID}:${ALUNO_ID}" "/home/${ALUNO_ID}/.ssh"
chmod 700 "/home/${ALUNO_ID}/.ssh"
chmod 600 "/home/${ALUNO_ID}/.ssh/authorized_keys"

log "Usuário ${ALUNO_ID} criado com sucesso"

# =============================================================================
# Configurar AWS CLI com credenciais do aluno
# =============================================================================
log "Configurando AWS CLI para ${ALUNO_ID}..."
sudo -u "${ALUNO_ID}" aws configure set aws_access_key_id "${ACCESS_KEY}"
sudo -u "${ALUNO_ID}" aws configure set aws_secret_access_key "${SECRET_KEY}"
sudo -u "${ALUNO_ID}" aws configure set default.region "${AWS_REGION}"
sudo -u "${ALUNO_ID}" aws configure set default.output json

log "AWS CLI configurado"

# =============================================================================
# Clonar repositório do curso
# =============================================================================
log "Clonando repositório do curso..."
cd "/home/${ALUNO_ID}"
sudo -u "${ALUNO_ID}" git clone https://github.com/DevWizardsOps/Curso-opensearch.git >> "${LOG_FILE}" 2>&1 || {
  log "[WARN] Falha ao clonar repositório. Continuando..."
}

# Remover diretório preparacao-curso da cópia do aluno (é do instrutor)
sudo -u "${ALUNO_ID}" rm -rf "/home/${ALUNO_ID}/Curso-opensearch/preparacao-curso"
log "Repositório clonado e preparacao-curso removido"

# Configurar timezone
timedatectl set-timezone America/Sao_Paulo >> "${LOG_FILE}" 2>&1 || true

# =============================================================================
# Criar arquivo de boas-vindas
# =============================================================================
cat > "/home/${ALUNO_ID}/BEM-VINDO.txt" << 'EOFWELCOME'
╔══════════════════════════════════════════════════════════════╗
║         BEM-VINDO AO CURSO AWS OPENSEARCH SERVICE            ║
║                     Módulo 6                                 ║
╚══════════════════════════════════════════════════════════════╝

Olá ALUNO_PLACEHOLDER!

Seu ambiente está configurado e pronto para uso.

📋 INFORMAÇÕES DO AMBIENTE:
  - Usuário Linux: ALUNO_PLACEHOLDER
  - Região AWS: REGION_PLACEHOLDER

🔧 FERRAMENTAS INSTALADAS:
  ✓ AWS CLI, curl, jq, git

🚀 PRIMEIROS PASSOS:
  1. Teste suas credenciais: aws sts get-caller-identity
  2. Acesse o Lab 0: cd ~/Curso-opensearch/modulo6-lab/lab0-setup/
  3. Siga o README.md para criar seu OpenSearch Domain
  4. Configure as variáveis: ./configurar-ambiente.sh
  5. Valide a conexão: ./testar-conexao.sh
  6. Inicie os labs: cd ~/Curso-opensearch/modulo6-lab/lab1-bulk/

⚠️  IMPORTANTE:
  Você precisa criar seu próprio OpenSearch Domain no Lab 0
  antes de iniciar os demais labs.

Bom curso! 🎓
EOFWELCOME

# Substituir placeholders
sed -i "s/ALUNO_PLACEHOLDER/${ALUNO_ID}/g" "/home/${ALUNO_ID}/BEM-VINDO.txt"
sed -i "s/REGION_PLACEHOLDER/${AWS_REGION}/g" "/home/${ALUNO_ID}/BEM-VINDO.txt"

# =============================================================================
# Customizar .bashrc
# =============================================================================
cat >> "/home/${ALUNO_ID}/.bashrc" << 'EOFBASHRC'

# Aliases úteis — Curso OpenSearch
alias ll='ls -lah'
alias curso='cd ~/Curso-opensearch/modulo6-lab'
alias lab0='cd ~/Curso-opensearch/modulo6-lab/lab0-setup'
alias awsid='aws sts get-caller-identity'

# Mostrar boas-vindas no login
cat ~/BEM-VINDO.txt

export ALUNO_ID=ALUNO_ID_PLACEHOLDER
EOFBASHRC

sed -i "s/ALUNO_ID_PLACEHOLDER/${ALUNO_ID}/g" "/home/${ALUNO_ID}/.bashrc"

# =============================================================================
# Ajustar permissões finais
# =============================================================================
chown -R "${ALUNO_ID}:${ALUNO_ID}" "/home/${ALUNO_ID}/"

# Marcar setup como completo
echo "Setup completo em $(date)" > "/home/${ALUNO_ID}/setup-complete.txt"
chown "${ALUNO_ID}:${ALUNO_ID}" "/home/${ALUNO_ID}/setup-complete.txt"

log "Setup concluído com sucesso para ${ALUNO_ID}"

exit 0
