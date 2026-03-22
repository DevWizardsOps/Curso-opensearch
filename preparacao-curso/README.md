# Preparação do Curso — AWS OpenSearch Service

Scripts para provisionamento, gerenciamento e configuração do ambiente de laboratório do curso **Módulo 6 — Laboratórios e Troubleshooting com AWS OpenSearch**.

## Pré-requisitos

- **AWS CLI v2** configurado com credenciais válidas
- **jq** instalado (`sudo yum install jq` ou `brew install jq`)
- **curl** instalado (disponível por padrão na maioria dos sistemas)
- Conta AWS com permissões para criar: CloudFormation, OpenSearch, EC2, IAM, VPC

## Scripts Disponíveis

| Script | Descrição |
|---|---|
| `deploy-curso.sh` | Provisiona toda a infraestrutura AWS via CloudFormation |
| `gerar-template.sh` | Gera o template CloudFormation YAML dinamicamente |
| `manage-curso.sh` | Gerencia o ciclo de vida do ambiente (status, start, stop, cleanup) |
| `setup-aluno.sh` | Configura o ambiente do aluno na EC2 bastion |
| `test-ambiente.sh` | Valida que o ambiente está funcional e acessível |

## Ordem de Execução

### Para o Instrutor (provisionamento)

```bash
# 1. Deploy do ambiente
./deploy-curso.sh --region us-east-1 --alunos 5

# 2. Verificar se o ambiente está funcional
./test-ambiente.sh

# 3. Gerenciar o ambiente
./manage-curso.sh status
./manage-curso.sh info
```

### Para o Aluno (configuração)

```bash
# 1. Executado na EC2 bastion após acesso SSH
./setup-aluno.sh --endpoint https://seu-dominio.us-east-1.es.amazonaws.com \
                 --user admin \
                 --pass SuaSenha123!

# 2. Verificar conectividade
./test-ambiente.sh
```

## Infraestrutura Provisionada

O `deploy-curso.sh` cria via CloudFormation:

- **VPC** com subnet pública
- **Security Group** com portas 443 (HTTPS) e 5601 (Dashboards)
- **IAM Role + Policy** com permissões mínimas para OpenSearch
- **Amazon OpenSearch Service Domain** (`t3.small.search`, 1 nó, 10GB EBS gp3)
- **EC2 Bastion** (`t3.micro`) para acesso dos alunos

### Custo Estimado

| Recurso | Custo/hora | Custo/dia |
|---|---|---|
| OpenSearch t3.small.search | ~$0.036 | ~$0.86 |
| EC2 t3.micro | ~$0.0104 | ~$0.25 |
| EBS 10GB gp3 | — | ~$0.08 |
| **Total estimado** | — | **~$1.19/dia** |

> ⚠️ Lembre-se de executar `./manage-curso.sh cleanup` ao final do curso para evitar custos desnecessários.

## Limpeza do Ambiente

```bash
# Remover toda a infraestrutura (com confirmação)
./manage-curso.sh cleanup

# Remover sem confirmação (uso em scripts)
./manage-curso.sh force-clean
```
