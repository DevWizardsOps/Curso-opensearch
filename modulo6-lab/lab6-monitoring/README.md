# Lab 6 — Monitoramento do Cluster

## Objetivo

Usar as **APIs nativas do OpenSearch** para monitorar a saúde do cluster, sem depender de ferramentas externas como Grafana, Prometheus ou Logstash.

## APIs de Monitoramento

### `_cluster/health`

Retorna o estado geral de saúde do cluster.

```bash
GET /_cluster/health?pretty
```

**Campos principais:**

| Campo                    | Descrição                                              |
|--------------------------|--------------------------------------------------------|
| `status`                 | `green` = saudável, `yellow` = réplicas não alocadas, `red` = shards primários não alocados |
| `number_of_nodes`        | Total de nós no cluster                                |
| `active_primary_shards`  | Shards primários ativos                                |
| `unassigned_shards`      | Shards não alocados (0 = ideal)                        |
| `relocating_shards`      | Shards em processo de realocação                       |

**Interpretação do status:**
- 🟢 `green`: todos os shards primários e réplicas estão alocados
- 🟡 `yellow`: shards primários OK, mas réplicas não alocadas (comum em cluster de 1 nó)
- 🔴 `red`: um ou mais shards primários não estão alocados — **dados podem estar inacessíveis**

### `_cat/nodes`

Exibe informações de cada nó do cluster em formato tabular.

```bash
GET /_cat/nodes?v&h=name,ip,heap.percent,ram.percent,cpu,load_1m,node.role
```

**Campos principais:**

| Campo          | Descrição                                              |
|----------------|--------------------------------------------------------|
| `name`         | Nome do nó                                             |
| `ip`           | Endereço IP do nó                                      |
| `heap.percent` | % de heap JVM usada — alerta se > 75%                  |
| `ram.percent`  | % de RAM total usada                                   |
| `cpu`          | % de CPU usada                                         |
| `load_1m`      | Load average do último minuto                          |
| `node.role`    | `m` = master, `d` = data, `i` = ingest, `r` = remote  |

**Thresholds de alerta:**
- `heap.percent` > 75%: risco de GC pressure e OOM
- `cpu` > 80%: cluster sobrecarregado
- `load_1m` > número de CPUs: sistema saturado

### `_cat/indices`

Lista todos os índices com métricas de tamanho e documentos.

```bash
GET /_cat/indices?v&s=store.size:desc
```

**Campos principais:**

| Campo        | Descrição                                              |
|--------------|--------------------------------------------------------|
| `health`     | `green`/`yellow`/`red` — saúde do índice               |
| `status`     | `open`/`close`                                         |
| `index`      | Nome do índice                                         |
| `docs.count` | Número de documentos                                   |
| `store.size` | Tamanho em disco (inclui réplicas)                     |
| `pri.store.size` | Tamanho dos shards primários                       |

## Pré-requisitos

- Variáveis de ambiente configuradas:
  ```bash
  export OPENSEARCH_ENDPOINT="https://seu-dominio.us-east-1.es.amazonaws.com"
  export OPENSEARCH_USER="admin"
  export OPENSEARCH_PASS="sua-senha"
  ```
- `curl` e `jq` instalados
- **Não é necessário setup** — este lab usa o cluster existente

## Passo a Passo

```bash
# Verificar saúde geral do cluster (com alertas coloridos)
./cluster-health.sh

# Listar nós e métricas de recursos
./cat-nodes.sh

# Listar índices ordenados por tamanho
./cat-indices.sh

# Executar todos os scripts em sequência
./monitorar-tudo.sh
```

## Resultado Esperado

- `cluster-health.sh`: exibe status em verde (green), amarelo (yellow) ou vermelho (red)
- `cat-nodes.sh`: tabela com heap%, cpu, load de cada nó
- `cat-indices.sh`: lista de índices ordenada por tamanho decrescente
- `monitorar-tudo.sh`: output consolidado das três APIs com separadores visuais

## Arquivos

| Arquivo              | Descrição                                              |
|----------------------|--------------------------------------------------------|
| `cluster-health.sh`  | GET /_cluster/health com alertas coloridos             |
| `cat-nodes.sh`       | GET /_cat/nodes com métricas de recursos               |
| `cat-indices.sh`     | GET /_cat/indices ordenado por tamanho                 |
| `monitorar-tudo.sh`  | Executa os três scripts em sequência                   |

> **Nota**: Este lab não possui `setup.sh` nem `cleanup.sh` — usa apenas o cluster existente e não cria recursos.
