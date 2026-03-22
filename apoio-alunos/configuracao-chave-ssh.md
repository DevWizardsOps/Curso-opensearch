# 🔑 Configuração de Chave SSH

Este documento orienta alunos que ainda não possuem uma chave SSH configurada para acessar o ambiente do curso.

---

## 📋 Cenários Cobertos

- [Cenário A](#cenário-a--você-recebeu-um-arquivo-pem-do-instrutor) — Você recebeu um arquivo `.pem` do instrutor
- [Cenário B](#cenário-b--você-precisa-gerar-uma-nova-chave-ssh) — Você precisa gerar uma nova chave SSH
- [Cenário C](#cenário-c--baixar-a-chave-do-s3) — Sua chave está armazenada em um bucket S3

---

## Cenário A — Você recebeu um arquivo `.pem` do instrutor

### 1. Mova a chave para um local seguro

```bash
# Linux / macOS
mv ~/Downloads/aluno01.pem ~/.ssh/aluno01.pem

# Windows (Git Bash ou WSL)
mv /c/Users/SeuUsuario/Downloads/aluno01.pem ~/.ssh/aluno01.pem
```

### 2. Ajuste as permissões da chave

Este passo é obrigatório — o SSH recusa chaves com permissões muito abertas.

```bash
chmod 400 ~/.ssh/aluno01.pem
```

Verifique:

```bash
ls -la ~/.ssh/aluno01.pem
# Saída esperada: -r-------- 1 usuario grupo ... aluno01.pem
```

### 3. Teste a conexão

```bash
ssh -i ~/.ssh/aluno01.pem alunoXX@SEU-IP-PUBLICO
```

---

## Cenário B — Você precisa gerar uma nova chave SSH

Use este cenário se o instrutor solicitou que você gere sua própria chave e envie a chave pública.

### 1. Gere o par de chaves

```bash
ssh-keygen -t rsa -b 4096 -C "aluno01@curso-opensearch" -f ~/.ssh/aluno01
```

Quando solicitado, você pode deixar a senha em branco (pressione Enter) para facilitar o uso durante o curso.

Saída esperada:

```
Generating public/private rsa key pair.
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /home/usuario/.ssh/aluno01
Your public key has been saved in /home/usuario/.ssh/aluno01.pub
```

### 2. Verifique os arquivos gerados

```bash
ls -la ~/.ssh/aluno01*
# -rw------- aluno01      (chave privada — NUNCA compartilhe)
# -rw-r--r-- aluno01.pub  (chave pública — envie ao instrutor)
```

### 3. Envie a chave pública ao instrutor

```bash
cat ~/.ssh/aluno01.pub
```

Copie o conteúdo e envie ao instrutor. Ele irá registrar sua chave pública no servidor.

### 4. Ajuste as permissões da chave privada

```bash
chmod 400 ~/.ssh/aluno01
```

### 5. Teste a conexão após o instrutor confirmar o registro

```bash
ssh -i ~/.ssh/aluno01 alunoXX@SEU-IP-PUBLICO
```

---

## Cenário C — Baixar a chave do S3

Se o instrutor disponibilizou a chave em um bucket S3, siga os passos abaixo.

### Pré-requisito: AWS CLI configurado

```bash
aws sts get-caller-identity
```

Se retornar erro, configure suas credenciais:

```bash
aws configure
# AWS Access Key ID: (fornecido pelo instrutor)
# AWS Secret Access Key: (fornecido pelo instrutor)
# Default region name: us-east-1
# Default output format: json
```

### Baixe a chave do S3

```bash
aws s3 cp s3://NOME-DO-BUCKET/chaves/aluno01.pem ~/.ssh/aluno01.pem
```

> Substitua `NOME-DO-BUCKET` e `aluno01.pem` pelos valores fornecidos pelo instrutor.

### Ajuste as permissões

```bash
chmod 400 ~/.ssh/aluno01.pem
```

### Teste a conexão

```bash
ssh -i ~/.ssh/aluno01.pem alunoXX@SEU-IP-PUBLICO
```

---

## 🪟 Instruções para Windows

### Usando Git Bash (recomendado)

Os comandos acima funcionam normalmente no Git Bash. Certifique-se de que o Git Bash está instalado.

### Usando o PowerShell nativo

```powershell
# Ajustar permissões no Windows (equivalente ao chmod 400)
icacls "C:\Users\SeuUsuario\.ssh\aluno01.pem" /inheritance:r /grant:r "$($env:USERNAME):(R)"

# Conectar via SSH
ssh -i C:\Users\SeuUsuario\.ssh\aluno01.pem alunoXX@SEU-IP-PUBLICO
```

---

## ❓ Problemas Comuns

### Erro: `WARNING: UNPROTECTED PRIVATE KEY FILE!`

```bash
chmod 400 ~/.ssh/aluno01.pem
```

### Erro: `Permission denied (publickey)`

Possíveis causas:
- Arquivo de chave incorreto (verifique o nome com o instrutor)
- Usuário SSH incorreto (verifique se está usando `alunoXX` correto)
- Chave pública ainda não registrada no servidor (aguarde confirmação do instrutor)

### Erro: `No such file or directory` ao executar ssh-keygen

O diretório `~/.ssh` não existe. Crie-o:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
```

### Erro ao baixar do S3: `An error occurred (AccessDenied)`

Suas credenciais AWS não têm permissão para acessar o bucket. Verifique com o instrutor se as credenciais estão corretas e se o bucket está acessível.

```bash
# Verificar credenciais configuradas
aws sts get-caller-identity

# Listar objetos do bucket para testar acesso
aws s3 ls s3://NOME-DO-BUCKET/chaves/
```
