# 🎓 Apoio aos Alunos — Amazon OpenSearch Service

Bem-vindo ao módulo de apoio! Aqui você encontra tudo que precisa para acessar e configurar seu ambiente de laboratório.

---

## 📋 Índice de Documentos

| Documento | Descrição |
|---|---|
| [🔑 Configuração de Chave SSH](./configuracao-chave-ssh.md) | Gerar e configurar sua chave SSH antes do primeiro acesso |
| [🖥️ Acesso SSH à EC2](./acesso-ssh.md) | Conectar-se à instância EC2 bastion via SSH |
| [🌐 Acesso ao OpenSearch Dashboards](./acesso-dashboards.md) | Acessar a interface web do OpenSearch via túnel SSH |

---

## 🚀 Por Onde Começar

Siga esta ordem no seu primeiro acesso:

1. **Verifique se você tem uma chave SSH** → [Configuração de Chave SSH](./configuracao-chave-ssh.md)
2. **Conecte-se à instância EC2** → [Acesso SSH](./acesso-ssh.md)
3. **Acesse o OpenSearch Dashboards** → [Acesso ao Dashboards](./acesso-dashboards.md)

---

## 🏗️ Visão Geral do Ambiente

```
Seu computador
     │
     │  SSH (porta 22)
     ▼
EC2 Bastion (IP público fornecido pelo instrutor)
     │
     │  VPC interna (porta 443)
     ▼
Amazon OpenSearch Service Domain
     │
     │  Porta 5601 (via túnel SSH)
     ▼
OpenSearch Dashboards (acessível em https://localhost:5601)
```

O ambiente é composto por:

- **EC2 Bastion** — instância `t3.micro` que serve como ponto de entrada seguro
- **OpenSearch Domain** — instância `t3.small.search` com OpenSearch 2.11
- **OpenSearch Dashboards** — interface web acessível via túnel SSH na porta 5601

---

## 📦 Ferramentas Necessárias

Você precisará ter instalado no seu computador:

- **SSH client** — já disponível no Linux/macOS; no Windows use o terminal do Git Bash ou WSL
- **Navegador web** — para acessar o OpenSearch Dashboards

Nas instâncias EC2, as seguintes ferramentas já estão configuradas:

```bash
curl --version   # cliente HTTP para chamadas à API
jq --version     # processador JSON
aws --version    # AWS CLI para interação com serviços AWS
```

---

## ℹ️ Informações do Ambiente

O instrutor fornecerá as seguintes informações antes do início do curso:

| Informação | Exemplo |
|---|---|
| IP público do bastion | `54.123.45.67` |
| Nome do arquivo de chave | `aluno01.pem` |
| Usuário SSH | `alunoXX` (ex: `aluno01`) |
| Endpoint do OpenSearch | `search-curso-xxx.us-east-1.es.amazonaws.com` |

---

## ❓ Problemas Comuns

**Não recebi as informações de acesso**
→ Entre em contato com o instrutor antes do início do lab.

**Esqueci qual documento consultar**
→ Siga sempre a ordem: Chave SSH → Acesso SSH → Dashboards.

**O ambiente não está respondendo**
→ Verifique com o instrutor se o ambiente foi iniciado. Use `manage-curso.sh status` se tiver acesso ao script.
