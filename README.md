# 🎓 Curso AWS OpenSearch Service — Módulo 6

Laboratórios Práticos de Operação, Otimização e Troubleshooting no Amazon OpenSearch Service.

## 📚 Estrutura do Módulo

### Laboratórios Disponíveis

| Lab | Título | Duração | Descrição |
|-----|--------|---------|-----------|
| **00** | [Criação do Ambiente OpenSearch](./modulo6-lab/lab0-setup/) | 30min | Criar domínio OpenSearch, configurar variáveis e validar conectividade |
| **01** | [Bulk Indexing](./modulo6-lab/lab1-bulk/) | 20min | Comparar ingestão individual vs bulk e medir throughput |
| **02** | [Filter vs Query Context](./modulo6-lab/lab2-query/) | 20min | Diferença de performance entre filter context e query context |
| **03** | [Diagnóstico de Latência](./modulo6-lab/lab3-latency/) | 25min | Usar Profile API para identificar gargalos em queries |
| **04** | [Oversharding](./modulo6-lab/lab4-sharding/) | 30min | Impacto de configurações excessivas de shards na performance |
| **05** | [Query Pesada Controlada](./modulo6-lab/lab5-query-heavy/) | 25min | Wildcard + aggregation vs abordagem otimizada com term query |
| **06** | [Monitoramento do Cluster](./modulo6-lab/lab6-monitoring/) | 20min | APIs nativas de monitoramento (`_cluster/health`, `_cat/nodes`, `_cat/indices`) |
| **07** | [Troubleshooting Controlado](./modulo6-lab/lab7-troubleshooting/) | 30min | Identificar e corrigir problema de mapping incorreto |

**Duração Total:** ~3.5 horas de laboratórios práticos

## 🚀 Para Instrutores

### Preparação do Ambiente AWS

Os scripts de preparação estão no diretório [`preparacao-curso/`](./preparacao-curso/):

```bash
cd preparacao-curso/

# 1. Deploy automático do ambiente
./deploy-curso.sh

# 2. Testar configuração
./test-ambiente.sh
```

**O que é criado automaticamente:**
- ✅ VPC com subnets pública e privada
- ✅ Instâncias EC2 (t3.micro) para cada aluno
- ✅ Usuários IAM com permissões para OpenSearch, EC2, CloudWatch, S3
- ✅ Chaves SSH geradas automaticamente
- ✅ AWS CLI pré-configurado em cada EC2
- ✅ Ferramentas instaladas: curl, jq, git
- ✅ Repositório do curso clonado no home do aluno

**O que NÃO é criado:**
- ❌ OpenSearch Domain — cada aluno cria o seu no Lab 0

### Gerenciamento do Ambiente

```bash
cd preparacao-curso/

./manage-curso.sh status                    # Ver estado das instâncias
./manage-curso.sh stop                      # Parar instâncias (economia)
./manage-curso.sh start                     # Iniciar instâncias
./manage-curso.sh connect aluno01           # SSH para instância do aluno
./manage-curso.sh costs                     # Estimativa de custos
./manage-curso.sh cleanup                   # Remover TUDO (com confirmação)
```

## 👨‍🎓 Para Alunos

### 🚀 Guias de Configuração Inicial

**IMPORTANTE**: Antes de começar qualquer laboratório, siga os guias de apoio:

📚 **[Acesse os Guias de Apoio](./apoio-alunos/README.md)**

Os guias vão te ajudar a:
1. 🔑 Baixar a chave SSH do S3
2. 🔌 Conectar à sua instância EC2
3. ✅ Verificar que o ambiente está funcionando

**Tempo estimado**: 15 minutos

### Pré-requisitos

- Conhecimento básico de busca e indexação
- Familiaridade com conceitos de cloud computing
- Acesso à instância EC2 fornecida pelo instrutor

### Resumo Rápido (Após Seguir os Guias)

**Conectar via SSH**:
```bash
ssh -i nome-da-chave.pem alunoXX@SEU-IP-PUBLICO
```

**Verificar configuração**:
```bash
aws sts get-caller-identity  # Ver suas credenciais
aws configure get region     # Deve retornar a região configurada
echo $ALUNO_ID               # Ver seu ID de aluno
```

**Criar seu OpenSearch Domain (Lab 0)**:
```bash
cd ~/Curso-opensearch/modulo6-lab/lab0-setup/
./criar-dominio.sh
```

**Iniciar os labs**:
```bash
cd ~/Curso-opensearch/modulo6-lab/lab1-bulk/
./setup.sh
```

## 🎯 Objetivos de Aprendizado

Ao final do módulo, você será capaz de:

- ✅ **Criar** e configurar um domínio Amazon OpenSearch Service
- ✅ **Comparar** estratégias de ingestão (individual vs bulk)
- ✅ **Otimizar** queries usando filter context vs query context
- ✅ **Diagnosticar** latência com a Profile API
- ✅ **Dimensionar** shards corretamente (evitar oversharding)
- ✅ **Identificar** queries custosas e aplicar otimizações
- ✅ **Monitorar** saúde do cluster com APIs nativas
- ✅ **Troubleshoot** problemas de mapping e reindexar dados

## 🛠️ Ferramentas Utilizadas

| Ferramenta | Uso |
|------------|-----|
| **curl** | Requisições HTTP às APIs do OpenSearch |
| **jq** | Parsing e formatação de JSON |
| **AWS CLI** | Criação do domínio OpenSearch e gerenciamento AWS |
| **bash** | Scripts de automação dos labs |

> Nenhuma ferramenta externa é necessária além de `curl`, `jq` e `aws-cli`.

## 💰 Custos do Laboratório

### Estimativa por Aluno/Dia
| Recurso | Custo/dia |
|---------|-----------|
| EC2 t3.micro | ~$0.25 |
| OpenSearch t3.small.search | ~$0.86 |
| NAT Gateway | ~$1.08 |
| EBS (10GB) | ~$0.08 |
| **Total** | **~$2.27/dia** |

### Otimização de Custos
- ✅ Usar `./manage-curso.sh stop` para parar EC2 fora do horário
- ✅ Alunos devem deletar o OpenSearch Domain ao final do curso
- ✅ Instrutor executa `./manage-curso.sh cleanup` para remover tudo
- ✅ Monitorar custos no AWS Cost Explorer

## 🔒 Segurança

### Implementado no Ambiente
- ✅ **Princípio do menor privilégio** para IAM
- ✅ **Security Groups** restritivos (SSH apenas)
- ✅ **Encryption at rest** habilitada no OpenSearch
- ✅ **HTTPS obrigatório** para o domínio OpenSearch
- ✅ **Fine-grained access control** com master user
- ✅ **Chaves SSH** únicas por curso
- ✅ **Senhas** armazenadas no AWS Secrets Manager

## 📖 Recursos Adicionais

### Documentação Oficial
- [Amazon OpenSearch Service Developer Guide](https://docs.aws.amazon.com/opensearch-service/)
- [OpenSearch Documentation](https://opensearch.org/docs/latest/)
- [OpenSearch REST API Reference](https://opensearch.org/docs/latest/api-reference/)

### APIs Utilizadas nos Labs
- [Bulk API](https://opensearch.org/docs/latest/api-reference/document-apis/bulk/)
- [Search API](https://opensearch.org/docs/latest/api-reference/search/)
- [Profile API](https://opensearch.org/docs/latest/api-reference/profile/)
- [Cluster Health](https://opensearch.org/docs/latest/api-reference/cluster-api/cluster-health/)
- [CAT APIs](https://opensearch.org/docs/latest/api-reference/cat/index/)

## 🆘 Suporte

### Problemas Comuns
| Problema | Solução |
|----------|---------|
| Conexão SSH falha | Verificar IP, chave `.pem` e `chmod 400` |
| AWS CLI sem credenciais | Executar `aws configure` ou pedir ao instrutor |
| OpenSearch inacessível | Verificar access policy do domínio e endpoint |
| Variáveis de ambiente vazias | Executar `./configurar-ambiente.sh` no Lab 0 |
| Domínio ainda "Processing" | Aguardar 15-20 minutos após criação |

### Comandos de Diagnóstico
```bash
# Verificar credenciais AWS
aws sts get-caller-identity

# Testar conexão com OpenSearch
curl -s -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" "${OPENSEARCH_ENDPOINT}/_cluster/health" | jq .

# Verificar variáveis de ambiente
echo "ENDPOINT: $OPENSEARCH_ENDPOINT"
echo "USER: $OPENSEARCH_USER"
echo "ALUNO: $ALUNO_ID"
```

---

**Bem-vindo aos Laboratórios Práticos de OpenSearch! 🔍**

*Domine operação, otimização e troubleshooting em ambientes de produção.*
