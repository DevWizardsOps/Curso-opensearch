# 🌐 Acesso ao OpenSearch Dashboards

O OpenSearch Dashboards é a interface web para visualização e consulta de dados. O acesso é feito via **túnel SSH** que redireciona a porta 5601 do seu computador para o endpoint do OpenSearch.

---

## 📋 Pré-requisitos

- [ ] Você já consegue se conectar à EC2 via SSH (veja [Acesso SSH](./acesso-ssh.md))
- [ ] Você tem o IP do bastion e o endpoint do OpenSearch (fornecidos pelo instrutor)
- [ ] Seu navegador está disponível no computador local

---

## 🔧 Criando o Túnel SSH

### Sintaxe do comando

```bash
ssh -i chave.pem -L 5601:OPENSEARCH_ENDPOINT:443 alunoXX@BASTION_IP
```

### Exemplo real

```bash
ssh -i aluno01.pem -L 5601:search-curso-abc123.us-east-1.es.amazonaws.com:443 aluno01@54.123.45.67
```

> **O que esse comando faz:** Cria um túnel que redireciona `localhost:5601` no seu computador para a porta `443` do endpoint do OpenSearch, passando pelo bastion.

### Parâmetros explicados

| Parâmetro | Descrição |
|---|---|
| `-i chave.pem` | Arquivo de chave SSH |
| `-L 5601:ENDPOINT:443` | Túnel local: porta 5601 local → porta 443 do OpenSearch |
| `alunoXX@BASTION_IP` | Usuário e IP do bastion |

---

## 🌍 Acessando pelo Navegador

Com o túnel ativo (terminal aberto com o comando acima), abra o navegador e acesse:

```
https://localhost:5601
```

> **Atenção:** Use `https://` (não `http://`). O OpenSearch exige conexão segura.

### Aviso de certificado

Na primeira vez, o navegador pode exibir um aviso de certificado não confiável. Isso é esperado porque o certificado é do endpoint AWS, não do `localhost`. Clique em **"Avançado"** → **"Continuar para localhost"** (ou equivalente no seu navegador).

### Login no Dashboards

Use as credenciais fornecidas pelo instrutor:

| Campo | Valor |
|---|---|
| Username | `admin` (ou conforme instrutor) |
| Password | Fornecida pelo instrutor |

---

## 💡 Mantendo o Túnel Ativo

O túnel SSH precisa ficar aberto enquanto você usa o Dashboards. Recomendações:

**Opção 1 — Terminal dedicado (recomendado para iniciantes)**

Abra um terminal separado só para o túnel e deixe-o aberto durante o lab.

**Opção 2 — Túnel em background**

```bash
ssh -i chave.pem -L 5601:OPENSEARCH_ENDPOINT:443 -N -f alunoXX@BASTION_IP
```

O `-N` não executa comandos remotos e o `-f` coloca o processo em background.

Para encerrar o túnel em background:

```bash
# Encontrar o processo
ps aux | grep ssh

# Encerrar pelo PID
kill <PID>
```

---

## 🔍 Explorando o Dashboards

Após fazer login, você pode:

- **Dev Tools** → Executar queries diretamente na API do OpenSearch (menu lateral esquerdo)
- **Discover** → Explorar documentos indexados
- **Index Management** → Ver e gerenciar índices

Para acessar o Dev Tools rapidamente:

```
https://localhost:5601/app/dev_tools
```

Exemplo de query no Dev Tools:

```
GET _cluster/health
```

---

## ❓ Problemas Comuns

### Navegador exibe "Esta página não está funcionando" ou "ERR_CONNECTION_REFUSED"

O túnel SSH não está ativo. Verifique se o terminal com o comando `ssh -L` ainda está aberto.

### Aviso de certificado não aparece, mas a página não carrega

Tente acessar com `https://` (não `http://`):

```
https://localhost:5601
```

### Erro de login: "Invalid username or password"

Confirme as credenciais com o instrutor. As credenciais são configuradas durante o provisionamento do ambiente.

### Túnel cai durante o lab

Reabra o terminal e execute novamente o comando de túnel. A sessão no Dashboards pode precisar ser recarregada no navegador.

### Porta 5601 já está em uso

Se outra aplicação usa a porta 5601, use uma porta alternativa:

```bash
ssh -i chave.pem -L 5602:OPENSEARCH_ENDPOINT:443 alunoXX@BASTION_IP
```

E acesse pelo navegador em `https://localhost:5602`.
