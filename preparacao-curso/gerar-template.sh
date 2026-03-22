#!/bin/bash
set -e

# =============================================================================
# Preparação do Curso — Gerar Template CloudFormation
# Gera o template YAML para provisionamento do ambiente OpenSearch
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
ALUNOS=1
OUTPUT_FILE="template-opensearch.yaml"

# Parse de argumentos
while [[ $# -gt 0 ]]; do
  case $1 in
    --alunos)  ALUNOS="$2"; shift 2 ;;
    --output)  OUTPUT_FILE="$2"; shift 2 ;;
    --help|-h)
      echo "Uso: $0 [--alunos N] [--output FILE]"
      echo ""
      echo "Opções:"
      echo "  --alunos N      Número de alunos (padrão: 1)"
      echo "  --output FILE   Arquivo de saída (padrão: template-opensearch.yaml)"
      exit 0
      ;;
    *) error "Argumento desconhecido: $1"; exit 1 ;;
  esac
done

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Gerar Template CloudFormation          ${NC}"
echo -e "${BLUE}  OpenSearch Service                     ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

log "Alunos: ${ALUNOS}"
log "Arquivo de saída: ${OUTPUT_FILE}"
echo ""

log "Gerando template CloudFormation..."

cat > "${OUTPUT_FILE}" << 'TEMPLATE_START'
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Curso AWS OpenSearch Service - Modulo 6 - Laboratorios e Troubleshooting'

Parameters:
  MasterUser:
    Type: String
    Default: 'admin'
    Description: 'Usuario master do OpenSearch'
  MasterPassword:
    Type: String
    NoEcho: true
    MinLength: 8
    Description: 'Senha master do OpenSearch (minimo 8 caracteres, deve conter maiuscula, minuscula, numero e caractere especial)'
  KeyPairName:
    Type: AWS::EC2::KeyPair::KeyName
    Description: 'Nome do Key Pair para acesso SSH ao bastion'
  LatestAmiId:
    Type: AWS::SSM::Parameter::Value<AWS::EC2::Image::Id>
    Default: '/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64'
    Description: 'AMI ID do Amazon Linux 2023'

Resources:
  # ============================================================
  # VPC e Networking
  # ============================================================
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: '10.0.0.0/16'
      EnableDnsSupport: true
      EnableDnsHostnames: true
      Tags:
        - Key: Name
          Value: !Sub 'curso-opensearch-vpc'

  PublicSubnet:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: '10.0.1.0/24'
      MapPublicIpOnLaunch: true
      AvailabilityZone: !Select [0, !GetAZs '']
      Tags:
        - Key: Name
          Value: !Sub 'curso-opensearch-public-subnet'

  InternetGateway:
    Type: AWS::EC2::InternetGateway
    Properties:
      Tags:
        - Key: Name
          Value: 'curso-opensearch-igw'

  AttachGateway:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      VpcId: !Ref VPC
      InternetGatewayId: !Ref InternetGateway

  PublicRouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: 'curso-opensearch-public-rt'

  PublicRoute:
    Type: AWS::EC2::Route
    DependsOn: AttachGateway
    Properties:
      RouteTableId: !Ref PublicRouteTable
      DestinationCidrBlock: '0.0.0.0/0'
      GatewayId: !Ref InternetGateway

  SubnetRouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PublicSubnet
      RouteTableId: !Ref PublicRouteTable

  # ============================================================
  # Security Groups
  # ============================================================
  BastionSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: 'SSH access to bastion host'
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          CidrIp: '0.0.0.0/0'
      Tags:
        - Key: Name
          Value: 'curso-opensearch-bastion-sg'

  OpenSearchSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: 'OpenSearch access from bastion'
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          SourceSecurityGroupId: !Ref BastionSecurityGroup
        - IpProtocol: tcp
          FromPort: 5601
          ToPort: 5601
          SourceSecurityGroupId: !Ref BastionSecurityGroup
      Tags:
        - Key: Name
          Value: 'curso-opensearch-domain-sg'

TEMPLATE_START

# Append IAM and OpenSearch resources
cat >> "${OUTPUT_FILE}" << 'TEMPLATE_MIDDLE'
  # ============================================================
  # IAM Role e Policy
  # ============================================================
  OpenSearchRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub 'curso-opensearch-role-${AWS::Region}'
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: ec2.amazonaws.com
            Action: 'sts:AssumeRole'
      Tags:
        - Key: Name
          Value: 'curso-opensearch-role'

  OpenSearchPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: 'CursoOpenSearchPolicy'
      Roles:
        - !Ref OpenSearchRole
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Sid: OpenSearchAccess
            Effect: Allow
            Action:
              - 'es:ESHttpGet'
              - 'es:ESHttpPost'
              - 'es:ESHttpPut'
              - 'es:ESHttpDelete'
              - 'es:ESHttpHead'
              - 'es:DescribeDomain'
              - 'es:ListDomainNames'
              - 'opensearch:ESHttpGet'
              - 'opensearch:ESHttpPost'
              - 'opensearch:ESHttpPut'
              - 'opensearch:ESHttpDelete'
              - 'opensearch:ESHttpHead'
            Resource:
              - !Sub 'arn:aws:es:${AWS::Region}:${AWS::AccountId}:domain/curso-opensearch-*'
              - !Sub 'arn:aws:es:${AWS::Region}:${AWS::AccountId}:domain/curso-opensearch-*/*'
          - Sid: CloudFormationRead
            Effect: Allow
            Action:
              - 'cloudformation:DescribeStacks'
              - 'cloudformation:DescribeStackEvents'
            Resource: '*'

  BastionInstanceProfile:
    Type: AWS::IAM::InstanceProfile
    Properties:
      Roles:
        - !Ref OpenSearchRole

  # ============================================================
  # OpenSearch Domain
  # ============================================================
  OpenSearchDomain:
    Type: AWS::OpenSearchService::Domain
    Properties:
      DomainName: !Sub 'curso-opensearch'
      EngineVersion: 'OpenSearch_2.11'
      ClusterConfig:
        InstanceType: t3.small.search
        InstanceCount: 1
        DedicatedMasterEnabled: false
        ZoneAwarenessEnabled: false
      EBSOptions:
        EBSEnabled: true
        VolumeType: gp3
        VolumeSize: 10
      NodeToNodeEncryptionOptions:
        Enabled: true
      EncryptionAtRestOptions:
        Enabled: true
      DomainEndpointOptions:
        EnforceHTTPS: true
      AdvancedSecurityOptions:
        Enabled: true
        InternalUserDatabaseEnabled: true
        MasterUserOptions:
          MasterUserName: !Ref MasterUser
          MasterUserPassword: !Ref MasterPassword
      VPCOptions:
        SubnetIds:
          - !Ref PublicSubnet
        SecurityGroupIds:
          - !Ref OpenSearchSecurityGroup
      AccessPolicies:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              AWS: !GetAtt OpenSearchRole.Arn
            Action: 'es:*'
            Resource: !Sub 'arn:aws:es:${AWS::Region}:${AWS::AccountId}:domain/curso-opensearch/*'
      Tags:
        - Key: Name
          Value: 'curso-opensearch-domain'
        - Key: Projeto
          Value: 'Curso-OpenSearch-Modulo6'

  # ============================================================
  # EC2 Bastion
  # ============================================================
  BastionHost:
    Type: AWS::EC2::Instance
    DependsOn: OpenSearchDomain
    Properties:
      InstanceType: t3.micro
      KeyName: !Ref KeyPairName
      ImageId: !Ref LatestAmiId
      SubnetId: !Ref PublicSubnet
      SecurityGroupIds:
        - !Ref BastionSecurityGroup
      IamInstanceProfile: !Ref BastionInstanceProfile
      Tags:
        - Key: Name
          Value: 'curso-opensearch-bastion'
        - Key: Projeto
          Value: 'Curso-OpenSearch-Modulo6'

TEMPLATE_MIDDLE

# Append Outputs
cat >> "${OUTPUT_FILE}" << 'TEMPLATE_END'
Outputs:
  OpenSearchEndpoint:
    Description: 'Endpoint do dominio OpenSearch'
    Value: !Sub 'https://${OpenSearchDomain.DomainEndpoint}'
    Export:
      Name: !Sub '${AWS::StackName}-OpenSearchEndpoint'

  OpenSearchDashboardsURL:
    Description: 'URL do OpenSearch Dashboards'
    Value: !Sub 'https://${OpenSearchDomain.DomainEndpoint}/_dashboards'
    Export:
      Name: !Sub '${AWS::StackName}-DashboardsURL'

  BastionPublicIP:
    Description: 'IP publico do bastion host'
    Value: !GetAtt BastionHost.PublicIp
    Export:
      Name: !Sub '${AWS::StackName}-BastionIP'

  BastionSSHCommand:
    Description: 'Comando SSH para acessar o bastion'
    Value: !Sub 'ssh -i <sua-chave.pem> ec2-user@${BastionHost.PublicIp}'

  VPCId:
    Description: 'ID da VPC criada'
    Value: !Ref VPC

  OpenSearchDomainArn:
    Description: 'ARN do dominio OpenSearch'
    Value: !GetAtt OpenSearchDomain.Arn
TEMPLATE_END

success "Template gerado: ${OUTPUT_FILE}"
echo ""

# Exibe resumo dos recursos
log "Recursos no template:"
echo -e "  • VPC + Subnet + Internet Gateway"
echo -e "  • Security Groups (Bastion + OpenSearch)"
echo -e "  • IAM Role + Policy (permissões mínimas)"
echo -e "  • OpenSearch Domain (t3.small.search, 1 nó, 10GB gp3)"
echo -e "  • EC2 Bastion (t3.micro)"
echo ""

# Conta linhas do template
LINES=$(wc -l < "${OUTPUT_FILE}" | tr -d ' ')
log "Template gerado com ${LINES} linhas."
echo ""
