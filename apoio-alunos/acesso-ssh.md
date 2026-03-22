# 🖥️ Acesso SSH à Instância EC2 Bastion

Este documento explica como se conectar à instância EC2 bastion que serve como ponto de entrada para o ambiente do curso.

---

## 📋 Pré-requisitos

Antes de continuar, certifique-se de que:

- [ ] Você possui o arquivo de chave `.pem` (veja [Configuração de Chave SSH](./configuracao-chave-ssh.md) se não tiver)
- [ ] O instrutor forneceu o **IP público** do bastion e seu **usuário** (ex: `aluno01`)
- [ ] Você está em uma rede com acesso à internet

---

## 🔑 Conectando via SSH

### Sintaxe do comando

```bash
ssh -i nome-da-chave.pem alunoXX@SEU-IP-PUBLICO
```

### Exemplo real

```bash
ssh -i aluno01.pem aluno01@54.123.45.67
```

> **Atenção:** Substitua `aluno01.pem`, `aluno01` e `54.123.45.67` pelos valores fornecidos pelo instrutor.

---

## ✅ Verificando o Ambiente

Após conectar, execute os comandos abaixo para confirmar que o ambiente está configurado corretamente:

### 1. Verificar identidade AWS

```bash
aws sts get-caller-identity
```

Saída esperada (exemplo):

```json
{
    "UserId": "AROAXXXXXXXXXXXXXXXXX:aluno01",
    "Account": "123456789012",
    "Arn": "arn:aws:sts::123456789012:assumed-role/CursoOpenSearchRole/aluno01"
}
```

### 2. Verificar curl

```bash
curl --version
```

Saída esperada (exemplo):

```
curl 7.88.1 (x86_64-redhat-linux-gnu) libcurl/7.88.1 OpenSSL/3.0.7
```

### 3. Verificar jq

```bash
jq --version
```

Saída esperada:

```
jq-1.6
```

### 4. Verificar variáveis de ambiente do OpenSearch

```bash
echo $OPENSEARCH_ENDPOINT
echo $OPENSEARCH_USER
echo $AWS_REGION
```

Se as variáveis estiverem vazias, execute:

```bash
source ~/.bashrc
```

---

## 📁 Navegando no Repositório do Curso

Após conectar, o repositório já estará clonado no diretório home:

```bash
ls ~/curso-opensearch-modulo6/
```

Para acessar os labs:

```bash
cd ~/curso-opensearch-modulo6/modulo6-lab/lab1-bulk/
ls -la
```

---

## ❓ Problemas Comuns

### Erro: `Permission denied (publickey)`

A chave não está sendo reconhecida. Verifique:

```bash
# A permissão da chave deve ser 400
chmod 400 nome-da-chave.pem

# Tente novamente
ssh -i nome-da-chave.pem alunoXX@SEU-IP-PUBLICO
```

### Erro: `WARNING: UNPROTECTED PRIVATE KEY FILE!`

As permissões da chave estão muito abertas. Corrija com:

```bash
chmod 400 nome-da-chave.pem
```

### Erro: `Connection timed out`

- Verifique se o IP fornecido está correto
- Confirme com o instrutor se a instância EC2 está em execução
- Verifique se sua rede não bloqueia a porta 22

### Erro: `Host key verification failed`

Se você já se conectou antes e o IP mudou:

```bash
ssh-keygen -R SEU-IP-PUBLICO
ssh -i nome-da-chave.pem alunoXX@SEU-IP-PUBLICO
```

### Variáveis de ambiente não definidas após login

```bash
source ~/.bashrc
echo $OPENSEARCH_ENDPOINT
```

Se ainda estiver vazio, entre em contato com o instrutor para reexecutar o `setup-aluno.sh`.
