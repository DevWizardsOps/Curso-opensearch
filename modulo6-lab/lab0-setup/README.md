# 🔧 Lab 0 — Criação do Ambiente OpenSearch

## 🎯 Objetivo

Criar e configurar seu próprio domínio Amazon OpenSearch Service a partir da sua instância EC2. Este é o **primeiro lab do curso** e deve ser executado antes de qualquer outro exercício.

Ao final deste lab, você terá:
- Um domínio OpenSearch ativo e acessível
- Variáveis de ambiente configuradas (`OPENSEARCH_ENDPOINT`, `OPENSEARCH_USER`, `OPENSEARCH_PASS`)
- Conectividade validada com o cluster

---

## 📋 Pré-requisitos

Antes de iniciar, confirme que:

1. **EC2 configurada pelo instrutor** — você está conectado via SSH à sua instância EC2 dedicada
2. **AWS CLI funcionando** — execute o comando abaixo para verificar:

```bash
aws sts get-caller-identity
```

Você deve ver seu `UserId`, `Account` e `Arn`. Se houver erro, peça ajuda ao instrutor.

3. **Credenciais IAM ativas** — suas credenciais de acesso (AccessKey/SecretKey) já foram configuradas automaticamente pelo script de setup da EC2

---

## 🚀 Passo a Passo

### 1️⃣ Criar o Domínio OpenSearch

Você pode criar o domínio de duas formas: via **Console AWS** ou via **AWS CLI**. Escolha a que preferir.

#### Opção A — Via Console AWS

1. Acesse o console AWS no navegador: `https://console.aws.amazon.com/`
2. Navegue até **Amazon OpenSearch Service**
3. Clique em **Create domain**
4. Configure:
   - **Domain name**: `opensearch-aluno` (ou um nome de sua escolha)
   - **Deployment type**: Development and testing
   - **Version**: escolha a versão mais recente disponível (OpenSearch 2.x)
5. Em **Data nodes**:
   - **Instance type**: `t3.small.search`
   - **Number of nodes**: `1`
   - **EBS storage size per node**: `10` GB (tipo `gp3`)
6. Em **Network**:
   - **Network**: Public access
7. Em **Fine-grained access control**:
   - Marque **Enable fine-grained access control**
   - Selecione **Create master user**
   - **Master username**: `admin` (ou outro de sua escolha)
   - **Master password**: escolha uma senha forte (mínimo 8 caracteres, com maiúscula, minúscula, número e caractere especial)
8. Em **Access policy**:
   - Selecione **Only use fine-grained access control**
9. Em **Encryption**:
   - Mantenha **Encryption at rest** e **Node-to-node encryption** habilitados
   - Marque **Require HTTPS for all traffic**
10. Clique em **Create**

#### Opção B — Via AWS CLI

Execute o script helper que cria o domínio com os parâmetros recomendados:

```bash
./criar-dominio.sh
```

Ou, se preferir executar o comando manualmente:

```bash
aws opensearch create-domain \
  --domain-name "opensearch-aluno" \
  --engine-version "OpenSearch_2.13" \
  --cluster-config '{"InstanceType":"t3.small.search","InstanceCount":1}' \
  --ebs-options '{"EBSEnabled":true,"VolumeType":"gp3","VolumeSize":10}' \
  --node-to-node-encryption-options '{"Enabled":true}' \
  --encryption-at-rest-options '{"Enabled":true}' \
  --domain-endpoint-options '{"EnforceHTTPS":true}' \
  --advanced-security-options '{
    "Enabled":true,
    "InternalUserDatabaseEnabled":true,
    "MasterUserOptions":{
      "MasterUserName":"admin",
      "MasterUserPassword":"SuaSenhaForte123!"
    }
  }'
```

> ⚠️ **Substitua** `SuaSenhaForte123!` por uma senha forte de sua escolha. Anote o usuário e a senha — você precisará deles nos próximos passos.


### 2️⃣ Aguardar a Criação do Domínio

⏱️ **Tempo estimado: 15 a 20 minutos**

A criação do domínio OpenSearch leva algum tempo. Você pode acompanhar o status:

**Via Console AWS:**
- Acesse Amazon OpenSearch Service → Domains
- O status mudará de `Processing` para `Active`

**Via AWS CLI:**

```bash
aws opensearch describe-domain --domain-name "opensearch-aluno" \
  --query 'DomainStatus.Processing'
```

Quando retornar `false`, o domínio está pronto.

Para obter o endpoint:

```bash
aws opensearch describe-domain --domain-name "opensearch-aluno" \
  --query 'DomainStatus.Endpoint' --output text
```

> 💡 **Dica**: enquanto aguarda, aproveite para revisar o material do curso ou explorar a documentação do OpenSearch.

---

### 3️⃣ Configurar Variáveis de Ambiente

Após o domínio estar ativo, configure as variáveis de ambiente que serão usadas em **todos os labs**:

```bash
./configurar-ambiente.sh
```

O script solicitará:
- **Endpoint do OpenSearch** (ex: `https://search-opensearch-aluno-xxxx.us-east-1.es.amazonaws.com`)
- **Usuário master** (ex: `admin`)
- **Senha master** (a senha que você definiu na criação)

As variáveis serão salvas no `~/.bashrc` e ativadas automaticamente:
- `OPENSEARCH_ENDPOINT`
- `OPENSEARCH_USER`
- `OPENSEARCH_PASS`

Verifique se foram configuradas:

```bash
echo $OPENSEARCH_ENDPOINT
echo $OPENSEARCH_USER
```

---

### 4️⃣ Testar Conectividade

Valide que o domínio está acessível e funcionando:

```bash
./testar-conexao.sh
```

O script executa um `curl` ao endpoint `/_cluster/health` e exibe:
- Status de saúde do cluster (`green`, `yellow` ou `red`)
- Confirmação de que o ambiente está pronto para os labs seguintes

---

## ✅ Resultado Esperado

Ao concluir este lab, você deve ter:

| Item | Status Esperado |
|---|---|
| Domínio OpenSearch | `Active` no console AWS |
| `OPENSEARCH_ENDPOINT` | Definida com a URL do domínio |
| `OPENSEARCH_USER` | Definida com o usuário master |
| `OPENSEARCH_PASS` | Definida com a senha master |
| Teste de conectividade | Cluster `green` ou `yellow` |

> 💡 **Status `yellow` é normal** para um cluster de 1 nó, pois não há réplicas disponíveis. Isso não impede a execução dos labs.

Após a validação, você está pronto para iniciar o **Lab 1 — Bulk Indexing**:

```bash
cd ../lab1-bulk/
```

---

## 🗂️ Arquivos do Lab

| Arquivo | Descrição |
|---|---|
| `criar-dominio.sh` | Script helper para criação do domínio via AWS CLI |
| `configurar-ambiente.sh` | Configura variáveis de ambiente (`OPENSEARCH_ENDPOINT`, `USER`, `PASS`) |
| `testar-conexao.sh` | Valida conectividade com o domínio OpenSearch |

---

## ⚠️ Solução de Problemas

**Domínio não fica ativo após 20 minutos**
→ Verifique no console AWS se há erros na criação. Causas comuns: limite de instâncias na conta, permissões IAM insuficientes.

**Erro: "User: arn:aws:iam::... is not authorized"**
→ Suas credenciais IAM podem não ter permissão para criar domínios OpenSearch. Peça ao instrutor para verificar a política IAM do seu usuário.

**Erro ao testar conectividade: "Could not resolve host"**
→ Verifique se o endpoint está correto. Copie o endpoint diretamente do console AWS (Amazon OpenSearch Service → Domains → seu domínio → Domain endpoint).

**Erro ao testar conectividade: "Connection refused" ou timeout**
→ Verifique:
  1. O domínio está no estado `Active`?
  2. O Security Group permite acesso da sua EC2?
  3. O endpoint inclui `https://` no início?

**Erro: "Unauthorized" ou "403 Forbidden"**
→ Verifique se o usuário e senha estão corretos. Lembre-se de que a senha é case-sensitive.

**Variáveis de ambiente não persistem após reconectar via SSH**
→ Execute `source ~/.bashrc` ou reconecte-se à EC2. As variáveis são salvas no `~/.bashrc` e carregadas automaticamente em novas sessões.
