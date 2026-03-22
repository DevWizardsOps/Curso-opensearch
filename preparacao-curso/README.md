# Preparação do Curso — AWS OpenSearch Service (Módulo 6)

Scripts de preparação do ambiente do curso, executados pelo **instrutor** antes do início das aulas.

## Arquitetura

O instrutor provisiona a infraestrutura base (VPC, EC2 por aluno, IAM Users) via CloudFormation. Cada aluno recebe uma instância EC2 pré-configurada e cria seu próprio OpenSearch Domain no **Lab 0**.

> **Importante:** O template CloudFormation **NÃO** cria OpenSearch Domain. O aluno cria no Lab 0 a partir da sua EC2.

## Pré-requisitos

- AWS CLI v2 instalado e configurado (`aws configure`)
- `jq` instalado
- `curl` instalado
- Credenciais AWS com permissões para: CloudFormation, EC2, IAM, S3, Secrets Manager

## Scripts

| Script | Descrição |
|---|---|
| `deploy-curso.sh` | Deploy interativo — cria toda a infraestrutura |
| `gerar-template.sh` | Gera o template CloudFormation YAML dinamicamente |
| `setup-aluno.sh` | Configuração automática da EC2 via UserData (executado no boot) |
| `manage-curso.sh` | Gerencia instâncias EC2 dos alunos (start/stop/status/cleanup) |
| `test-ambiente.sh` | Valida que a infraestrutura está funcional |

## Ordem de Execução

```
1. ./deploy-curso.sh          ← Provisiona tudo (interativo)
2. ./test-ambiente.sh          ← Valida infraestrutura
3. Alunos acessam EC2 via SSH
4. Alunos executam Lab 0       ← Criam OpenSearch Domain
5. Alunos iniciam Labs 1-7
```

## Deploy do Curso

```bash
cd preparacao-curso/
./deploy-curso.sh
```

O script solicita interativamente:
- Número de alunos (1-30)
- Prefixo do curso
- Nome da stack CloudFormation
- CIDR de acesso SSH
- Senha do console AWS para os alunos

Recursos criados:
- VPC com subnets pública e privada, Internet Gateway, NAT Gateway
- Security Group (SSH porta 22)
- IAM Group com permissões: `es:*`, `opensearch:*`, `ec2:*`, `cloudwatch:*`, `s3`, `kms`, `sts`
- IAM Role para EC2 (acesso S3)
- N × EC2 Instance (t3.micro) com UserData
- N × IAM User com AccessKey e LoginProfile
- S3 Bucket com scripts e chave SSH
- Secret no Secrets Manager com senha do console
- Relatório HTML com informações de acesso

## Gerenciamento

```bash
./manage-curso.sh status                          # Ver estado das instâncias
./manage-curso.sh start                           # Iniciar instâncias
./manage-curso.sh stop                            # Parar instâncias (economia)
./manage-curso.sh restart                         # Reiniciar instâncias
./manage-curso.sh info                            # Informações detalhadas da stack
./manage-curso.sh connect aluno1                  # SSH para instância do aluno
./manage-curso.sh costs                           # Estimativa de custos
./manage-curso.sh cleanup                         # Remover TUDO (com confirmação)
./manage-curso.sh force-clean                     # Remover TUDO (sem confirmação)
```

Opções disponíveis:
- `--stack-name NOME` — Nome da stack (padrão: `curso-opensearch-stack`)
- `--profile PERFIL` — Perfil AWS CLI

## Validação

```bash
./test-ambiente.sh --stack-name curso-opensearch-stack
```

Verifica:
- Stack CloudFormation em estado operacional
- Instâncias EC2 em estado `running`
- IAM Users com AccessKeys ativas
- S3 bucket com `setup-aluno.sh`
- Conectividade SSH

> **Nota:** O `test-ambiente.sh` **NÃO** valida OpenSearch Domain — isso é responsabilidade do aluno no Lab 0.

## Estimativa de Custos

| Recurso | Custo/dia (aprox.) |
|---|---|
| EC2 t3.micro (por aluno) | ~$0.25 |
| NAT Gateway | ~$1.08 |
| EBS 10GB gp3 (por aluno) | ~$0.08 |
| OpenSearch t3.small.search (por aluno, Lab 0) | ~$0.86 |

Para 5 alunos: ~$7.73/dia (incluindo OpenSearch criado pelos alunos).
