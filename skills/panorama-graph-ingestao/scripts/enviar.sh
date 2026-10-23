#!/usr/bin/env bash
# Envia ao panorama-graph os retratos de uma pasta de carga, pelo POST /v1/ingest.
#
# Uso: enviar.sh [--dry-run] [pasta]      (padrão: ./carga-grafo)
#
#   retratos/*.json   um retrato por arquivo (fonte, escopo, nós e relações), enviado em ordem de nome
#
# --dry-run    a API confere cada retrato e devolve as contagens de uma carga de verdade
#              (inclusive o que viraria stale), sem gravar nada
#
# Variáveis:
#   GRAPH_API_URL     panorama-graph-api (padrão: http://localhost:3200)
#   GRAPH_API_TOKEN   token da instância, mandado como Authorization: Bearer (o INGEST_TOKEN ou um JWT
#                     de um emissor confiável); sem ele, nada vai no cabeçalho
#
# Precisa de curl e jq. Saída 0: tudo gravado (ou conferido); 1: algum retrato recusado ou erro de uso.

set -euo pipefail

usage() { sed -n '2,/^$/{s/^# \{0,1\}//;p}' "${BASH_SOURCE[0]}"; }

dry=false
dir=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) dry=true ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "erro: opção desconhecida: $1" >&2; usage >&2; exit 1 ;;
    *) dir="$1" ;;
  esac
  shift
done
dir="${dir:-./carga-grafo}"
[[ -d "$dir/retratos" ]] || { echo "erro: $dir não tem a pasta retratos/" >&2; exit 1; }
for cmd in curl jq; do
  command -v "$cmd" >/dev/null || { echo "erro: precisa de $cmd" >&2; exit 1; }
done

api="${GRAPH_API_URL:-http://localhost:3200}"
api="${api%/}"
url="$api/v1/ingest"
$dry && url="$url?dryRun=true"
auth=()
[[ -n "${GRAPH_API_TOKEN:-}" ]] && auth=(-H "authorization: Bearer $GRAPH_API_TOKEN")

# Uma API sem dry-run ignoraria o parâmetro e gravaria: confere no OpenAPI dela antes de mandar qualquer retrato.
if $dry; then
  openapi="$(curl -sSf "${auth[@]}" "$api/v1/openapi.json")" \
    || { echo "erro: não consegui ler $api/v1/openapi.json" >&2; exit 1; }
  jq -e '[.paths["/v1/ingest"].post.parameters[]? | select(.name == "dryRun")] | length > 0' <<<"$openapi" >/dev/null \
    || { echo "erro: a API em $api não tem dry-run na ingestão (versão antiga). Atualize a API; nada foi enviado" >&2; exit 1; }
fi

shopt -s nullglob
files=("$dir"/retratos/*.json)
[[ ${#files[@]} -gt 0 ]] || { echo "erro: nenhum retrato em $dir/retratos" >&2; exit 1; }

$dry && echo "Conferindo em $api (dry-run: nada é gravado)" || echo "Enviando para $api"
failed=0
body="$(mktemp)"
trap 'rm -f "$body"' EXIT

for f in "${files[@]}"; do
  name="$(basename "$f")"
  if ! jq -e 'type == "object"' "$f" >/dev/null 2>&1; then
    echo "✗ $name: não é um JSON de objeto"
    failed=1
    continue
  fi
  status="$(curl -sS -o "$body" -w '%{http_code}' -X POST "$url" \
    -H 'content-type: application/json' "${auth[@]}" --data-binary "@$f")" || status=000

  if [[ "$status" == 200 ]]; then
    jq -r --arg f "$name" '
      def c(x): "+\(x.created) ~\(x.updated) =\(x.unchanged) stale \(x.stale)";
      "✓ \($f): \(.source) \(.scope | tojson)\n    nós \(c(.counts.nodes))   relações \(c(.counts.relations))   referenciados \(.counts.referenced)"
    ' "$body"
    continue
  fi

  failed=1
  if [[ "$status" == 000 ]]; then
    echo "✗ $name: a API não respondeu em $api"
  elif jq -e '.code' "$body" >/dev/null 2>&1; then
    jq -r --arg f "$name" --arg s "$status" '
      "✗ \($f): \($s) \(.code): \(.error)",
      ((.details.errors // [])[] | "    - \(.)")
    ' "$body"
  else
    echo "✗ $name: $status $(head -c 300 "$body")"
  fi
done

exit "$failed"
