#!/usr/bin/env bash
# Instala as skills do panorama-graph para agentes de IA.
#
# Uso: ./install.sh [opções] [skill ...]
#   Sem nomes de skill, instala todas as que estão em skills/.
#   Sem --claude nem --agents, pergunta para quais formatos instalar.
#
# Formatos:
#   claude    ~/.claude/skills, lido pelo Claude Code
#   agents    ~/.agents/skills, o diretório genérico de Agent Skills
#             (lido pelo Copilot no VS Code e por outros agentes)
#
# Opções:
#   --claude          instala no formato claude, sem perguntar
#   --agents          instala no formato agents, sem perguntar
#   --project DIR     instala no repositório DIR (DIR/.claude/skills, DIR/.agents/skills)
#                     em vez do diretório pessoal
#   --link            cria links simbólicos para este repositório em vez de copiar
#                     (um git pull aqui já atualiza as skills instaladas)
#   --schemas-ref REF tag, branch ou commit do repositório dos adaptadores de onde vêm
#                     os schemas dos formatos de build (padrão: PANORAMA_ADAPTERS_REF ou main)
#   --schemas-dir DIR copia os schemas de DIR (ex.: a pasta schemas/ de uma cópia local
#                     dos adaptadores) em vez de baixar
#   --product-ref REF tag, branch ou commit do repositório do produto de onde vêm os documentos
#                     do modelo (padrão: PANORAMA_GRAPH_REF ou main)
#   --product-dir DIR copia os documentos do modelo de DIR (a raiz de uma cópia local do
#                     panorama-graph) em vez de baixar
#   --uninstall       remove as skills indicadas dos formatos escolhidos
#   --list            lista as skills disponíveis
#   -h, --help        mostra esta ajuda
#
# Com os dois formatos, a skill é instalada em .agents/skills e .claude/skills/<skill>
# vira um link para ela, para existir uma cópia só.
#
# As skills que usam os schemas dos formatos de build (SCHEMA_SKILLS) os recebem em
# skills/<skill>/schemas/, baixados de github.com/panorama-graph/adapters (curl e tar).
# As que ensinam o modelo (PRODUCT_SKILLS) recebem em skills/<skill>/produto/ os documentos do
# modelo e da ingestão, baixados de github.com/panorama-graph/panorama-graph (curl).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$REPO_DIR/skills"
ADAPTERS_REPO="https://codeload.github.com/panorama-graph/adapters/tar.gz"
SCHEMA_SKILLS=(panorama-graph-carga-manual)
PRODUCT_RAW="https://raw.githubusercontent.com/panorama-graph/panorama-graph"
PRODUCT_SKILLS=(panorama-graph-ingestao)
PRODUCT_FILES=(api/MODELO.md api/ADAPTADOR.md api/PROVENIENCIA.md sdks/key-recipes.json)

claude=false
agents=false
project=""
link=false
uninstall=false
schemas_ref="${PANORAMA_ADAPTERS_REF:-main}"
schemas_dir=""
product_ref="${PANORAMA_GRAPH_REF:-main}"
product_dir=""
skills=()

usage() { sed -n '2,/^$/{s/^# \{0,1\}//;p}' "${BASH_SOURCE[0]}"; }

available() {
  for d in "$SKILLS_DIR"/*/; do
    [[ -f "$d/SKILL.md" ]] && basename "$d"
  done
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --claude) claude=true ;;
    --agents) agents=true ;;
    --project)
      [[ $# -ge 2 ]] || { echo "erro: --project precisa de um diretório" >&2; exit 1; }
      project="$2"; shift ;;
    --link) link=true ;;
    --schemas-ref)
      [[ $# -ge 2 ]] || { echo "erro: --schemas-ref precisa de uma ref" >&2; exit 1; }
      schemas_ref="$2"; shift ;;
    --schemas-dir)
      [[ $# -ge 2 && -d "$2" ]] || { echo "erro: --schemas-dir precisa de um diretório que exista" >&2; exit 1; }
      schemas_dir="$(cd "$2" && pwd)"; shift ;;
    --product-ref)
      [[ $# -ge 2 ]] || { echo "erro: --product-ref precisa de uma ref" >&2; exit 1; }
      product_ref="$2"; shift ;;
    --product-dir)
      [[ $# -ge 2 && -d "$2" ]] || { echo "erro: --product-dir precisa de um diretório que exista" >&2; exit 1; }
      product_dir="$(cd "$2" && pwd)"; shift ;;
    --uninstall) uninstall=true ;;
    --list) available; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "erro: opção desconhecida: $1" >&2; usage >&2; exit 1 ;;
    *) skills+=("$1") ;;
  esac
  shift
done

if [[ ${#skills[@]} -eq 0 ]]; then
  mapfile -t skills < <(available)
fi

for s in "${skills[@]}"; do
  if [[ ! -f "$SKILLS_DIR/$s/SKILL.md" ]]; then
    echo "erro: skill não encontrada: $s (veja ./install.sh --list)" >&2
    exit 1
  fi
done

if [[ -n "$project" ]]; then
  [[ -d "$project" ]] || { echo "erro: diretório não existe: $project" >&2; exit 1; }
  base="$(cd "$project" && pwd)"
else
  base="$HOME"
fi
claude_dest="$base/.claude/skills"
agents_dest="$base/.agents/skills"

# Pergunta os formatos quando nenhum foi passado na linha de comando.
if ! $claude && ! $agents; then
  if [[ ! -t 0 ]]; then
    echo "erro: sem terminal para perguntar; passe --claude e/ou --agents" >&2
    exit 1
  fi
  $uninstall && acao="Remover de" || acao="Instalar para"
  echo "Skills: ${skills[*]}"
  echo "$acao quais formatos?"
  echo "  1) claude  $claude_dest (Claude Code)"
  echo "  2) agents  $agents_dest (Copilot no VS Code e outros agentes)"
  while true; do
    read -r -p "Escolha um ou mais, separados por espaço [1 2]: " resposta
    resposta="${resposta:-1 2}"
    claude=false; agents=false; valida=true
    for r in ${resposta//,/ }; do
      case "$r" in
        1|claude) claude=true ;;
        2|agents) agents=true ;;
        *) valida=false ;;
      esac
    done
    if $valida && { $claude || $agents; }; then break; fi
    echo "Resposta inválida: use 1, 2 ou 1 2."
  done
  echo
fi

# Remove o destino só se for uma instalação de skill (link ou pasta com SKILL.md).
remove() {
  local target="$1"
  if [[ -L "$target" ]]; then
    rm -f "$target"
  elif [[ -f "$target/SKILL.md" ]]; then
    rm -rf "$target"
  elif [[ -e "$target" ]]; then
    echo "erro: $target existe e não parece uma skill; remova-o à mão" >&2
    exit 1
  else
    return 1
  fi
}

# Copia a skill para o destino, ou cria um link para este repositório com --link.
place() {
  local s="$1" target="$2"
  mkdir -p "$(dirname "$target")"
  remove "$target" || true
  if $link; then
    ln -s "$SKILLS_DIR/$s" "$target"
    echo "link:     $target -> $SKILLS_DIR/$s"
  else
    cp -RL "$SKILLS_DIR/$s" "$target"
    echo "copiada:  $target"
  fi
}

# Põe em skills/<skill>/schemas/ os schemas dos adaptadores, baixados uma vez por instalação.
schemas_cache=""
fetch_schemas() {
  local s="$1" dest="$SKILLS_DIR/$1/schemas"
  [[ " ${SCHEMA_SKILLS[*]} " == *" $s "* ]] || return 0
  if [[ -z "$schemas_cache" ]]; then
    if [[ -n "$schemas_dir" ]]; then
      schemas_cache="$schemas_dir"
    else
      schemas_tmp="$(mktemp -d)"
      trap 'rm -rf "$schemas_tmp" "${product_cache:-}"' EXIT
      curl -fsSL "$ADAPTERS_REPO/$schemas_ref" | tar xz -C "$schemas_tmp" \
        || { echo "erro: não consegui baixar os schemas dos adaptadores ($schemas_ref); use --schemas-dir" >&2; exit 1; }
      schemas_cache="$(echo "$schemas_tmp"/*/schemas)"
      [[ -d "$schemas_cache" ]] || { echo "erro: $schemas_ref não tem a pasta schemas/" >&2; exit 1; }
      echo "schemas:  panorama-graph/adapters@$schemas_ref"
    fi
  fi
  rm -rf "$dest"
  mkdir -p "$dest"
  cp "$schemas_cache"/*.json "$dest/"
}

# Põe em skills/<skill>/produto/ os documentos do modelo, baixados uma vez por instalação.
product_cache=""
fetch_product() {
  local s="$1" dest="$SKILLS_DIR/$1/produto" f
  [[ " ${PRODUCT_SKILLS[*]} " == *" $s "* ]] || return 0
  if [[ -z "$product_cache" ]]; then
    product_cache="$(mktemp -d)"
    trap 'rm -rf "${schemas_tmp:-}" "$product_cache"' EXIT
    for f in "${PRODUCT_FILES[@]}"; do
      if [[ -n "$product_dir" ]]; then
        cp "$product_dir/$f" "$product_cache/" \
          || { echo "erro: $product_dir não tem $f" >&2; exit 1; }
      else
        curl -fsSL "$PRODUCT_RAW/$product_ref/$f" -o "$product_cache/$(basename "$f")" \
          || { echo "erro: não consegui baixar $f do panorama-graph ($product_ref); use --product-dir" >&2; exit 1; }
      fi
    done
    [[ -n "$product_dir" ]] || echo "produto:  panorama-graph/panorama-graph@$product_ref"
  fi
  rm -rf "$dest"
  mkdir -p "$dest"
  cp "$product_cache"/* "$dest/"
}

for s in "${skills[@]}"; do
  if $uninstall; then
    for target in $($agents && echo "$agents_dest/$s") $($claude && echo "$claude_dest/$s"); do
      remove "$target" && echo "removida: $target" || true
    done
    continue
  fi

  fetch_schemas "$s"
  fetch_product "$s"
  if $agents; then
    place "$s" "$agents_dest/$s"
    if $claude; then
      remove "$claude_dest/$s" || true
      mkdir -p "$claude_dest"
      ln -s "$agents_dest/$s" "$claude_dest/$s"
      echo "link:     $claude_dest/$s -> $agents_dest/$s"
    fi
  else
    place "$s" "$claude_dest/$s"
  fi
done
