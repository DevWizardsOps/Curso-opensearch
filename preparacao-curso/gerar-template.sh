#!/bin/bash
set -e

# =============================================================================
# Preparação do Curso — Gerar Template CloudFormation
# Gera o template YAML dinamicamente com base no número de alunos
# Cada aluno recebe: EC2 Instance, IAM User com AccessKey, Outputs
# O template NÃO cria OpenSearch Domain (o aluno cria no Lab 0)
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

# ---------------------------------------------------------------------------
# Uso
# ---------------------------------------------------------------------------
usage() {
  echo "Uso: $0 <NUM_ALUNOS> [opções]"
  echo ""
  echo "Argumentos:"
  echo "  NUM_ALUNOS              Número de alunos (obrigatório, inteiro > 0)"
  echo ""
  echo "Opções:"
  echo "  --prefixo PREFIXO      Prefixo do curso (padrão: curso-opensearch)"
  echo "  --bucket BUCKET         Nome do bucket S3 (padrão: curso-opensearch-labs)"
  echo "  --secret SECRET         Nome do secret no Secrets Manager (padrão: curso-opensearch-senha)"
  echo "  --ssh-key KEY           Nome da chave SSH (padrão: curso-opensearch-key)"
  echo "  --cidr CIDR             CIDR de acesso (padrão: 0.0.0.0/0)"
  echo "  --output FILE           Arquivo de saída (padrão: template-opensearch.yaml)"
  echo "  --help, -h              Exibe esta ajuda"
  exit 0
}

# ---------------------------------------------------------------------------
# Parse de argumentos
# ---------------------------------------------------------------------------
NUM_ALUNOS=""
PREFIXO="curso-opensearch"
BUCKET="curso-opensearch-labs"
SECRET="curso-opensearch-senha"
SSH_KEY="curso-opensearch-key"
CIDR="0.0.0.0/0"
OUTPUT="template-opensearch.yaml"

# Primeiro argumento posicional = NUM_ALUNOS
if [[ $# -eq 0 ]]; then
  error "Número de alunos é obrigatório."
  echo "Uso: $0 <NUM_ALUNOS> [opções]"
  exit 1
fi

# Verifica se o primeiro argumento é --help
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  usage
fi

NUM_ALUNOS="$1"
shift

# Parse de parâmetros nomeados
while [[ $# -gt 0 ]]; do
  case $1 in
    --prefixo)  PREFIXO="$2"; shift 2 ;;
    --bucket)   BUCKET="$2"; shift 2 ;;
    --secret)   SECRET="$2"; shift 2 ;;
    --ssh-key)  SSH_KEY="$2"; shift 2 ;;
    --cidr)     CIDR="$2"; shift 2 ;;
    --output)   OUTPUT="$2"; shift 2 ;;
    --help|-h)  usage ;;
    *) error "Argumento desconhecido: $1"; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Validação de input
# ---------------------------------------------------------------------------
if ! [[ "$NUM_ALUNOS" =~ ^[0-9]+$ ]] || [[ "$NUM_ALUNOS" -le 0 ]]; then
  error "Número de alunos deve ser um inteiro positivo. Recebido: '${NUM_ALUNOS}'"
  echo "Uso: $0 <NUM_ALUNOS> [opções]"
  exit 1
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Gerar Template CloudFormation          ${NC}"
echo -e "${BLUE}  Curso OpenSearch — Módulo 6            ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

log "Número de alunos: ${NUM_ALUNOS}"
log "Prefixo: ${PREFIXO}"
log "Bucket S3: ${BUCKET}"
log "Secret: ${SECRET}"
log "Chave SSH: ${SSH_KEY}"
log "CIDR de acesso: ${CIDR}"
log "Arquivo de saída: ${OUTPUT}"
echo ""

log "Gerando template CloudFormation..."

# ---------------------------------------------------------------------------
# Início do template — Header + Parameters
# ---------------------------------------------------------------------------
cat > "${OUTPUT}" << EOF
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Curso AWS OpenSearch Service - Modulo 6 - Infraestrutura por aluno (VPC, EC2, IAM). O aluno cria o OpenSearch Domain no Lab 0.'

Parameters:
  NumAlunos:
    Type: Number
    Default: ${NUM_ALUNOS}
    Description: 'Numero de alunos do curso'

  Prefixo:
    Type: String
    Default: '${PREFIXO}'
    Description: 'Prefixo para nomes dos recursos'

  S3BucketName:
    Type: String
    Default: '${BUCKET}'
    Description: 'Nome do bucket S3 com scripts do curso'

  SecretName:
    Type: String
    Default: '${SECRET}'
    Description: 'Nome do secret no Secrets Manager com senha dos alunos'

  SSHKeyName:
    Type: AWS::EC2::KeyPair::KeyName
    Default: '${SSH_KEY}'
    Description: 'Nome do Key Pair SSH para acesso as instancias EC2'

  AccessCIDR:
    Type: String
    Default: '${CIDR}'
    Description: 'CIDR de acesso SSH as instancias EC2'

  LatestAmiId:
    Type: AWS::SSM::Parameter::Value<AWS::EC2::Image::Id>
    Default: '/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64'
    Description: 'AMI ID do Amazon Linux 2023'

EOF

# ---------------------------------------------------------------------------
# Conditions — dinâmicas por aluno
# ---------------------------------------------------------------------------
echo "Conditions:" >> "${OUTPUT}"

# Padrão de chain de conditions:
# - CriarAlunoN (último): !Equals [!Ref NumAlunos, "N"]
# - CriarAlunoI (I < N): !Or [!Equals [!Ref NumAlunos, "I"], !Condition CriarAluno(I+1)]
# - CriarAluno1 (se N=1): !Not [!Equals [!Ref NumAlunos, "0"]]
# - CriarAluno1 (se N>1): !Or [!Equals [!Ref NumAlunos, "1"], !Condition CriarAluno2]

if [[ "${NUM_ALUNOS}" -eq 1 ]]; then
  cat >> "${OUTPUT}" << 'EOF'
  CriarAluno1: !Not
    - !Equals
      - !Ref NumAlunos
      - "0"
EOF
else
  # Gerar de trás para frente: último aluno primeiro (base da chain)
  # Último aluno: CriarAlunoN = NumAlunos == N
  cat >> "${OUTPUT}" << EOF
  CriarAluno${NUM_ALUNOS}: !Equals
    - !Ref NumAlunos
    - "${NUM_ALUNOS}"
EOF

  # Alunos intermediários e primeiro (de N-1 até 1)
  for (( i=NUM_ALUNOS-1; i>=1; i-- )); do
    NEXT=$((i + 1))
    cat >> "${OUTPUT}" << EOF
  CriarAluno${i}: !Or
    - !Equals
      - !Ref NumAlunos
      - "${i}"
    - !Condition CriarAluno${NEXT}
EOF
  done
fi

echo "" >> "${OUTPUT}"

# ---------------------------------------------------------------------------
# Resources — Rede (estáticos)
# ---------------------------------------------------------------------------
cat >> "${OUTPUT}" << 'EOF'
Resources:
  # ============================================================
  # VPC e Networking
  # ============================================================
  CursoVPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: '10.0.0.0/16'
      EnableDnsSupport: true
      EnableDnsHostnames: true
      Tags:
        - Key: Name
          Value: !Sub '${Prefixo}-vpc'

  SubnetPublica:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref CursoVPC
      CidrBlock: '10.0.1.0/24'
      MapPublicIpOnLaunch: true
      AvailabilityZone: !Select [0, !GetAZs '']
      Tags:
        - Key: Name
          Value: !Sub '${Prefixo}-subnet-publica'

  SubnetPrivada:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref CursoVPC
      CidrBlock: '10.0.2.0/24'
      MapPublicIpOnLaunch: false
      AvailabilityZone: !Select [0, !GetAZs '']
      Tags:
        - Key: Name
          Value: !Sub '${Prefixo}-subnet-privada'

  InternetGateway:
    Type: AWS::EC2::InternetGateway
    Properties:
      Tags:
        - Key: Name
          Value: !Sub '${Prefixo}-igw'

  VPCGatewayAttachment:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      VpcId: !Ref CursoVPC
      InternetGatewayId: !Ref InternetGateway

  # --- Elastic IP e NAT Gateway (para subnet privada) ---
  NATElasticIP:
    Type: AWS::EC2::EIP
    DependsOn: VPCGatewayAttachment
    Properties:
      Domain: vpc
      Tags:
        - Key: Name
          Value: !Sub '${Prefixo}-nat-eip'

  NATGateway:
    Type: AWS::EC2::NatGateway
    Properties:
      AllocationId: !GetAtt NATElasticIP.AllocationId
      SubnetId: !Ref SubnetPublica
      Tags:
        - Key: Name
          Value: !Sub '${Prefixo}-nat-gw'

  # --- Route Tables ---
  PublicRouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref CursoVPC
      Tags:
        - Key: Name
          Value: !Sub '${Prefixo}-public-rt'

  PublicRoute:
    Type: AWS::EC2::Route
    DependsOn: VPCGatewayAttachment
    Properties:
      RouteTableId: !Ref PublicRouteTable
      DestinationCidrBlock: '0.0.0.0/0'
      GatewayId: !Ref InternetGateway

  SubnetRouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref SubnetPublica
      RouteTableId: !Ref PublicRouteTable

  PrivateRouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref CursoVPC
      Tags:
        - Key: Name
          Value: !Sub '${Prefixo}-private-rt'

  PrivateRoute:
    Type: AWS::EC2::Route
    Properties:
      RouteTableId: !Ref PrivateRouteTable
      DestinationCidrBlock: '0.0.0.0/0'
      NatGatewayId: !Ref NATGateway

  PrivateSubnetRouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref SubnetPrivada
      RouteTableId: !Ref PrivateRouteTable

  # ============================================================
  # Security Groups
  # ============================================================
  StudentSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: 'Security group for student EC2 instances - SSH access'
      VpcId: !Ref CursoVPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          CidrIp: !Ref AccessCIDR
      Tags:
        - Key: Name
          Value: !Sub '${Prefixo}-student-sg'

EOF

# ---------------------------------------------------------------------------
# Resources — IAM (estáticos)
# ---------------------------------------------------------------------------
cat >> "${OUTPUT}" << 'EOF'
  # ============================================================
  # IAM Group e Policy (permissões dos alunos)
  # ============================================================
  CursoIAMGroup:
    Type: AWS::IAM::Group
    Properties:
      GroupName: !Sub '${Prefixo}-alunos-group'

  CursoIAMPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: !Sub '${Prefixo}-alunos-policy'
      Groups:
        - !Ref CursoIAMGroup
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Sid: OpenSearchFullAccess
            Effect: Allow
            Action:
              - 'es:*'
              - 'opensearch:*'
            Resource: '*'
          - Sid: EC2Access
            Effect: Allow
            Action:
              - 'ec2:*'
            Resource: '*'
          - Sid: CloudWatchAccess
            Effect: Allow
            Action:
              - 'cloudwatch:*'
              - 'logs:*'
            Resource: '*'
          - Sid: S3Access
            Effect: Allow
            Action:
              - 's3:GetObject'
              - 's3:PutObject'
              - 's3:ListBucket'
            Resource: '*'
          - Sid: KMSAccess
            Effect: Allow
            Action:
              - 'kms:Decrypt'
              - 'kms:GenerateDataKey'
            Resource: '*'
          - Sid: STSAccess
            Effect: Allow
            Action:
              - 'sts:GetCallerIdentity'
            Resource: '*'

  # ============================================================
  # IAM Role para EC2 (acesso ao S3 bucket)
  # ============================================================
  EC2Role:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub '${Prefixo}-ec2-role'
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: ec2.amazonaws.com
            Action: 'sts:AssumeRole'
      Policies:
        - PolicyName: !Sub '${Prefixo}-ec2-s3-access'
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - 's3:GetObject'
                Resource: !Sub 'arn:aws:s3:::${S3BucketName}/*'

  EC2InstanceProfile:
    Type: AWS::IAM::InstanceProfile
    Properties:
      Roles:
        - !Ref EC2Role

EOF

# ---------------------------------------------------------------------------
# Resources — Dinâmicos por aluno (EC2, IAM User, AccessKey)
# ---------------------------------------------------------------------------
cat >> "${OUTPUT}" << 'EOF'
  # ============================================================
  # Recursos por aluno (EC2, IAM User, AccessKey)
  # ============================================================
EOF

for (( i=1; i<=NUM_ALUNOS; i++ )); do
  cat >> "${OUTPUT}" << EOF

  # --- Aluno ${i} ---
  EC2Aluno${i}:
    Type: AWS::EC2::Instance
    Condition: CriarAluno${i}
    Properties:
      InstanceType: t3.micro
      ImageId: !Ref LatestAmiId
      KeyName: !Ref SSHKeyName
      IamInstanceProfile: !Ref EC2InstanceProfile
      SubnetId: !Ref SubnetPublica
      SecurityGroupIds:
        - !Ref StudentSecurityGroup
      UserData:
        Fn::Base64: !Sub |
          #!/bin/bash
          aws s3 cp s3://\${S3BucketName}/setup-aluno.sh /tmp/setup-aluno.sh
          chmod +x /tmp/setup-aluno.sh
          /tmp/setup-aluno.sh "aluno$(printf '%02d' $i)" "\${AWS::Region}" "\${AccessKeyAluno${i}}" "\${AccessKeyAluno${i}.SecretAccessKey}"
      Tags:
        - Key: Name
          Value: !Sub '\${Prefixo}-aluno-$(printf '%02d' $i)'

  IAMUserAluno${i}:
    Type: AWS::IAM::User
    Condition: CriarAluno${i}
    Properties:
      UserName: !Sub '\${Prefixo}-aluno$(printf '%02d' $i)'
      Groups:
        - !Ref CursoIAMGroup
      LoginProfile:
        Password: !Sub '{{resolve:secretsmanager:\${SecretName}:SecretString:password}}'
        PasswordResetRequired: false

  AccessKeyAluno${i}:
    Type: AWS::IAM::AccessKey
    Condition: CriarAluno${i}
    Properties:
      UserName: !Ref IAMUserAluno${i}
EOF
done

echo "" >> "${OUTPUT}"

# ---------------------------------------------------------------------------
# Outputs — Estáticos + Dinâmicos por aluno
# ---------------------------------------------------------------------------
cat >> "${OUTPUT}" << 'EOF'
Outputs:
  VPCId:
    Description: 'ID da VPC criada'
    Value: !Ref CursoVPC

  S3BucketName:
    Description: 'Nome do bucket S3 do curso'
    Value: !Ref S3BucketName
EOF

for (( i=1; i<=NUM_ALUNOS; i++ )); do
  cat >> "${OUTPUT}" << EOF

  EC2Aluno${i}IP:
    Condition: CriarAluno${i}
    Description: 'IP publico da EC2 do aluno ${i}'
    Value: !GetAtt EC2Aluno${i}.PublicIp

  AccessKeyAluno${i}Output:
    Condition: CriarAluno${i}
    Description: 'Access Key do aluno ${i}'
    Value: !Ref AccessKeyAluno${i}

  SecretKeyAluno${i}:
    Condition: CriarAluno${i}
    Description: 'Secret Key do aluno ${i}'
    Value: !GetAtt AccessKeyAluno${i}.SecretAccessKey
EOF
done

echo "" >> "${OUTPUT}"

# ---------------------------------------------------------------------------
# Resumo
# ---------------------------------------------------------------------------
success "Template gerado: ${OUTPUT}"
echo ""

log "Recursos no template:"
echo -e "  • VPC + Subnets (pública + privada)"
echo -e "  • Internet Gateway + NAT Gateway"
echo -e "  • Route Tables (pública + privada)"
echo -e "  • Security Group (SSH porta 22)"
echo -e "  • IAM Group + Policy (es:*, opensearch:*, ec2:*, cloudwatch:*, s3, kms, sts)"
echo -e "  • IAM Role para EC2 (acesso S3)"
echo -e "  • ${NUM_ALUNOS}x EC2 Instance (t3.micro)"
echo -e "  • ${NUM_ALUNOS}x IAM User + AccessKey"
echo -e "  • ${NUM_ALUNOS}x Conditions dinâmicas"
echo ""

warning "O template NÃO cria OpenSearch Domain — o aluno cria no Lab 0."
echo ""

LINES=$(wc -l < "${OUTPUT}" | tr -d ' ')
log "Template gerado com ${LINES} linhas."
echo ""
