# 📦 Lab 1 — Bulk Indexing

## 🎯 Objetivo

Comparar a performance de ingestão de documentos no Amazon OpenSearch Service usando dois métodos:

- **Ingestão individual**: cada documento é enviado em uma requisição `POST /{index}/_doc` separada
- **Ingestão bulk**: todos os documentos são enviados em uma única requisição `POST /_bulk`

Ao final, você verá que a ingestão bulk é significativamente mais rápida, pois reduz o overhead de rede e de processamento por documento.

---

## 📋 Pré-requisitos

As variáveis de ambiente devem estar configuradas (feito no Lab 0). Verifique:

```bash
echo $OPENSEARCH_ENDPOINT
echo $OPENSEARCH_USER
echo $OPENSEARCH_PASS
```

Se alguma estiver vazia, configure executando o script do Lab 0:

```bash
cd ~/Curso-opensearch/modulo6-lab/lab0-setup/
./configurar-ambiente.sh
```

---

## 🚀 Passo a Passo

### 1️⃣ Setup — Criar o índice

```bash
./setup.sh
```

Cria o índice `lab1-produtos` com o mapping padrão do curso. Se o índice já existir, exibe um aviso e continua.

### 2️⃣ Ingestão Individual — Medir baseline

Para entender como funciona a ingestão individual, veja o curl equivalente:

```bash
# Exemplo: indexar UM documento via POST /{index}/_doc
curl -s -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X POST "${OPENSEARCH_ENDPOINT}/lab1-produtos/_doc" \
  -H "Content-Type: application/json" \
  -d '{"id":"1","nome":"Produto Teste","status":"ativo","descricao":"Exemplo de ingestão individual","usuario":"user_01","timestamp":"2024-01-15T10:30:00Z"}'
```

Cada documento exige uma requisição HTTP separada (conexão TCP + TLS + processamento).

Para medir o tempo com os 100 documentos do dataset, execute o script:

```bash
./ingestao-individual.sh
```

Ao final, exibe:
- Total de documentos enviados
- Tempo total de execução (em segundos)
- Taxa de ingestão (docs/segundo)

O resultado é salvo em `/tmp/lab1-individual-result.txt` para comparação posterior.

### 3️⃣ Ingestão Bulk — Medir performance otimizada

A API `_bulk` permite enviar múltiplos documentos em uma única requisição. O formato alterna entre uma linha de ação e uma linha de dados:

```bash
# Exemplo: indexar DOIS documentos em uma única requisição via POST /_bulk
curl -s -u "${OPENSEARCH_USER}:${OPENSEARCH_PASS}" \
  -X POST "${OPENSEARCH_ENDPOINT}/_bulk" \
  -H "Content-Type: application/json" \
  -d '
{"index":{"_index":"lab1-produtos"}}
{"id":"1","nome":"Produto A","status":"ativo","descricao":"Primeiro documento","usuario":"user_01","timestamp":"2024-01-15T10:30:00Z"}
{"index":{"_index":"lab1-produtos"}}
{"id":"2","nome":"Produto B","status":"inativo","descricao":"Segundo documento","usuario":"user_02","timestamp":"2024-02-20T14:45:00Z"}
'
```

Todo o overhead de rede ocorre apenas uma vez, independente do número de documentos.

Para medir o tempo com os 100 documentos do dataset, execute o script:

```bash
./ingestao-bulk.sh
```

Limpa o índice, recria-o via `setup.sh` e envia todos os documentos em uma única requisição bulk. Ao final, exibe:
- Total de documentos enviados
- Tempo total de execução (em segundos)
- Taxa de ingestão (docs/segundo)
- **Comparação automática** com o resultado da ingestão individual (se disponível)

### 4️⃣ Cleanup — Remover recursos criados

```bash
./cleanup.sh
```

Deleta o índice `lab1-produtos` e remove o arquivo de resultado temporário.

---

## ✅ Resultado Esperado

A ingestão bulk deve ser **significativamente mais rápida** que a ingestão individual. Em um cluster típico com 100 documentos, espera-se:

| Método | Tempo Estimado | Docs/segundo |
|---|---|---|
| Individual | 10–60 segundos | 2–10 docs/s |
| Bulk | < 2 segundos | 50–500 docs/s |

> 💡 **Por que bulk é mais rápido?**
> Cada requisição HTTP tem overhead de conexão TCP, handshake TLS e processamento no servidor. Com ingestão individual, esse overhead é multiplicado pelo número de documentos. Com bulk, o overhead ocorre apenas uma vez para todos os documentos.

---

## 🗂️ Arquivos do Lab

| Arquivo | Descrição |
|---|---|
| `setup.sh` | Cria o índice `lab1-produtos` com mapping padrão |
| `ingestao-individual.sh` | Envia documentos um a um e mede o tempo |
| `ingestao-bulk.sh` | Envia todos os documentos de uma vez e compara |
| `cleanup.sh` | Remove o índice e arquivos temporários |

---

## ⚠️ Solução de Problemas

**Erro: variável de ambiente não definida**
```
[ERRO] Variável OPENSEARCH_ENDPOINT não está definida.
```
→ Execute `cd ~/Curso-opensearch/modulo6-lab/lab0-setup/ && ./configurar-ambiente.sh` para configurar.

**Erro: OpenSearch não acessível**
```
[ERRO] OpenSearch não acessível em https://...
```
→ Verifique se o endpoint está correto e se você tem acesso de rede ao domínio.

**Erro: dataset não encontrado**
```
[ERRO] Dataset não encontrado em ../../dataset/dataset.json
```
→ Execute o lab a partir do diretório `modulo6-lab/lab1-bulk/` ou verifique se o dataset foi criado na tarefa 3.
