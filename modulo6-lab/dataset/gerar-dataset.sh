#!/bin/bash
# gerar-dataset.sh — Gerador de dataset no formato bulk API do OpenSearch
# Uso: ./gerar-dataset.sh [--count N] [--output FILE]
# Padrão: --count 100, saída para stdout

set -e

# ─── Configurações padrão ────────────────────────────────────────────────────
COUNT=100
OUTPUT=""

# ─── Parse de argumentos ─────────────────────────────────────────────────────
while [ $# -gt 0 ]; do
  case "$1" in
    --count)
      COUNT="$2"
      shift 2
      ;;
    --output)
      OUTPUT="$2"
      shift 2
      ;;
    -h|--help)
      echo "Uso: $0 [--count N] [--output FILE]"
      echo ""
      echo "  --count N      Número de documentos a gerar (padrão: 100)"
      echo "  --output FILE  Arquivo de saída (padrão: stdout)"
      exit 0
      ;;
    *)
      echo "[ERRO] Argumento desconhecido: $1" >&2
      echo "Use --help para ver as opções disponíveis." >&2
      exit 1
      ;;
  esac
done

# ─── Validação de argumentos ─────────────────────────────────────────────────
if ! echo "$COUNT" | grep -qE '^[0-9]+$' || [ "$COUNT" -lt 1 ]; then
  echo "[ERRO] --count deve ser um número inteiro positivo. Recebido: $COUNT" >&2
  exit 1
fi

# ─── Arrays de dados para geração realista ───────────────────────────────────
NOMES_BASE="Alpha Beta Gamma Delta Epsilon Zeta Eta Theta Iota Kappa Lambda Mu Nu Xi Omicron Pi Rho Sigma Tau Upsilon Phi Chi Psi Omega Apex Nexus Vertex Matrix Prism Flux"
DESCRICOES="Produto de alta qualidade para testes de indexação no OpenSearch|Item descontinuado aguardando remoção do catálogo de produtos|Produto em análise de conformidade antes de ser ativado no sistema|Solução robusta para ambientes de produção com alta disponibilidade|Componente essencial para integração com sistemas legados corporativos|Versão antiga substituída por modelo mais recente e eficiente|Aguardando aprovação do departamento de qualidade para liberação|Produto premium com suporte técnico dedicado e garantia estendida|Ferramenta de monitoramento para infraestrutura de nuvem distribuída|Em processo de certificação para mercados internacionais regulados|Módulo de processamento assíncrono para filas de alta demanda|Serviço legado em processo de migração para nova plataforma cloud|Biblioteca de criptografia para proteção de dados sensíveis em repouso|Produto aguardando testes de carga antes de entrar em produção|Conector de integração para APIs REST e serviços de mensageria|Dashboard analítico com visualizações em tempo real de métricas|Componente descontinuado após atualização de requisitos de segurança|Módulo em revisão de arquitetura para suporte a múltiplos tenants|Serviço de autenticação com suporte a OAuth2 e SAML federado|Plataforma de orquestração de containers para workloads críticos"

# ─── Funções auxiliares ───────────────────────────────────────────────────────

# Retorna o N-ésimo elemento (1-indexed) de uma lista separada por espaços
get_element() {
  local list="$1"
  local idx="$2"
  local count=0
  for item in $list; do
    count=$((count + 1))
    if [ "$count" -eq "$idx" ]; then
      echo "$item"
      return
    fi
  done
}

# Retorna o N-ésimo elemento (1-indexed) de uma lista separada por pipe
get_pipe_element() {
  local list="$1"
  local idx="$2"
  echo "$list" | tr '|' '\n' | sed -n "${idx}p"
}

# Conta elementos em lista separada por espaços
count_elements() {
  echo $#
}

# Retorna status baseado no índice (distribuição ~40% ativo, ~30% inativo, ~30% pendente)
get_status() {
  local idx="$1"
  local r=$((idx % 10))
  if [ "$r" -lt 4 ]; then
    echo "ativo"
  elif [ "$r" -lt 7 ]; then
    echo "inativo"
  else
    echo "pendente"
  fi
}

# Gera timestamp ISO 8601 variado em 2024
get_timestamp() {
  local idx="$1"
  local month=$(( (idx % 12) + 1 ))
  local day_opts="01 05 10 15 20 25 28"
  local day_idx=$(( (idx / 12) % 7 + 1 ))
  local day
  day=$(get_element "$day_opts" "$day_idx")
  local hour_opts="08 10 12 14 16"
  local hour_idx=$(( (idx / 84) % 5 + 1 ))
  local hour
  hour=$(get_element "$hour_opts" "$hour_idx")
  printf "2024-%02d-%sT%s:00:00Z" "$month" "$day" "$hour"
}

# Valida que um documento JSON contém os 6 campos obrigatórios
# Usa apenas bash sem jq (verificação por grep de padrão de chave JSON)
validate_document() {
  local doc="$1"
  local ok=0
  for field in id nome status descricao usuario timestamp; do
    if ! echo "$doc" | grep -q "\"${field}\""; then
      echo "[ERRO] Campo obrigatório ausente: ${field}" >&2
      ok=1
    fi
  done
  return $ok
}

# Escapa caracteres especiais para JSON (aspas duplas e barras invertidas)
json_escape() {
  echo "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# ─── Geração dos documentos ───────────────────────────────────────────────────

# Contar elementos dos arrays
NOMES_COUNT=30
DESCRICOES_COUNT=20

generate_dataset() {
  local i=1
  while [ "$i" -le "$COUNT" ]; do
    # Selecionar nome base (circular)
    local nome_idx=$(( (i - 1) % NOMES_COUNT + 1 ))
    local nome_base
    nome_base=$(get_element "$NOMES_BASE" "$nome_idx")
    local nome
    nome=$(printf "Produto %s %04d" "$nome_base" "$i")

    # Status distribuído
    local status
    status=$(get_status "$i")

    # Descrição (circular)
    local desc_idx=$(( (i - 1) % DESCRICOES_COUNT + 1 ))
    local descricao
    descricao=$(get_pipe_element "$DESCRICOES" "$desc_idx")

    # Usuário
    local user_num=$(( (i - 1) % 100 + 1 ))
    local usuario
    usuario=$(printf "user_%03d" "$user_num")

    # Timestamp variado em 2024
    local timestamp
    timestamp=$(get_timestamp "$i")

    # Montar documento JSON
    local doc
    doc="{\"id\": \"doc-$(printf '%04d' "$i")\", \"nome\": \"$(json_escape "$nome")\", \"status\": \"$status\", \"descricao\": \"$(json_escape "$descricao")\", \"usuario\": \"$usuario\", \"timestamp\": \"$timestamp\"}"

    # Validar documento
    if ! validate_document "$doc"; then
      echo "[ERRO] Documento $i inválido, abortando." >&2
      exit 1
    fi

    # Emitir par de linhas bulk API
    printf '{"index": {"_index": "produtos"}}\n'
    printf '%s\n' "$doc"

    i=$((i + 1))
  done
}

# ─── Execução ─────────────────────────────────────────────────────────────────

if [ -n "$OUTPUT" ]; then
  generate_dataset > "$OUTPUT"
  echo "[OK] Dataset com $COUNT documentos gerado em: $OUTPUT" >&2
else
  generate_dataset
fi
