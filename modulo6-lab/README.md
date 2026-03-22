# 🔍 Módulo 6 — Labs Práticos de Amazon OpenSearch Service

Bem-vindo ao módulo 6 do curso! Aqui você encontra 7 labs práticos que cobrem os principais aspectos de operação e otimização do Amazon OpenSearch Service.

---

## 📋 Visão Geral dos Labs

| # | Lab | Duração | Descrição |
|---|-----|---------|-----------|
| 1 | [Bulk Indexing](./lab1-bulk/README.md) | ~20 min | Compara ingestão individual vs bulk e mede throughput de cada abordagem |
| 2 | [Filter vs Query Context](./lab2-query/README.md) | ~20 min | Demonstra a diferença de performance entre filter context e query context |
| 3 | [Diagnóstico de Latência com Profile API](./lab3-latency/README.md) | ~25 min | Usa o endpoint `_profile` para identificar gargalos em queries lentas |
| 4 | [Oversharding](./lab4-sharding/README.md) | ~30 min | Observa o impacto de configurações excessivas de shards na performance |
| 5 | [Query Pesada Controlada](./lab5-query-heavy/README.md) | ~25 min | Compara wildcard + aggregation vs abordagem otimizada com term query |
| 6 | [Monitoramento do Cluster](./lab6-monitoring/README.md) | ~20 min | Usa APIs nativas (`_cluster/health`, `_cat/nodes`, `_cat/indices`) para monitorar o cluster |
| 7 | [Troubleshooting Controlado](./lab7-troubleshooting/README.md) | ~30 min | Identifica e corrige um problema de mapping incorreto em cenário reproduzível |

---

## 📦 Dataset Compartilhado

Todos os labs utilizam o mesmo dataset padrão, garantindo comparabilidade entre os exercícios.

### Arquivos disponíveis

| Arquivo | Documentos | Uso |
|---------|-----------|-----|
| [`dataset/dataset.json`](./dataset/dataset.json) | 100 | Labs 1, 2, 3, 4, 6, 7 |
| [`dataset/dataset-large.json`](./dataset/dataset-large.json) | 1000 | Lab 5 (query pesada) |
| [`dataset/gerar-dataset.sh`](./dataset/gerar-dataset.sh) | N (configurável) | Geração de volume customizado |

### Schema dos documentos

Cada documento contém os seguintes campos obrigatórios:

```json
{
  "id":        "doc-001",
  "nome":      "Produto Alpha 001",
  "status":    "ativo",
  "descricao": "Descrição do produto para testes de indexação no OpenSearch",
  "usuario":   "user_001",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

| Campo | Tipo | Valores |
|-------|------|---------|
| `id` | string | Identificador único no formato `doc-XXXX` |
| `nome` | string | Nome do produto (ex: `Produto Alpha 001`) |
| `status` | enum | `ativo` (~40%), `inativo` (~30%), `pendente` (~30%) |
| `descricao` | string | Texto livre de 50–100 caracteres |
| `usuario` | string | Usuário responsável (ex: `user_001`) |
| `timestamp` | ISO 8601 | Data/hora em UTC (ex: `2024-01-15T10:30:00Z`) |

### Gerando um dataset customizado

```bash
# Gerar 500 documentos para stdout
./dataset/gerar-dataset.sh --count 500

# Gerar 200 documentos para arquivo
./dataset/gerar-dataset.sh --count 200 --output meu-dataset.json
```

---

## ▶️ Padrão de Execução dos Labs

Cada lab segue o mesmo fluxo de três etapas:

```
1. setup.sh       → Cria índice e indexa o dataset (se necessário)
2. script principal → Executa o exercício (ex: ingestao-bulk.sh, query-context.sh)
3. cleanup.sh     → Remove os recursos criados pelo lab
```

### Exemplo — Lab 1

```bash
cd lab1-bulk/

# 1. Preparar o ambiente
./setup.sh

# 2. Executar os scripts do lab
./ingestao-individual.sh
./ingestao-bulk.sh

# 3. Limpar os recursos
./cleanup.sh
```

> ⚠️ **Importante:** Certifique-se de que as variáveis de ambiente estão configuradas antes de executar qualquer lab:
> ```bash
> export OPENSEARCH_ENDPOINT="https://seu-dominio.us-east-1.es.amazonaws.com"
> export OPENSEARCH_USER="admin"
> export OPENSEARCH_PASS="sua-senha"
> ```
> Essas variáveis são configuradas automaticamente pelo `setup-aluno.sh` em `~/.bashrc`.

---

## 🔗 Links Úteis

- [Apoio aos Alunos](../apoio-alunos/README.md) — Instruções de acesso ao ambiente
- [Preparação do Curso](../preparacao-curso/README.md) — Scripts de provisionamento AWS
- [Documentação OpenSearch](https://opensearch.org/docs/latest/)
