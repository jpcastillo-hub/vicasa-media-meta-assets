#!/usr/bin/env bash
# Sube un arte a una rama temporal de este repositorio para que Meta lo descargue por URL raw,
# y borra la rama al terminar. No llama a Meta: eso lo hace el agente con ads_creative_upload_media.
#
#   upload_to_meta_url.sh push <ruta-del-arte> <marca>
#   upload_to_meta_url.sh cleanup <rama>
#   upload_to_meta_url.sh list
#
# Variables opcionales: MAX_SIDE (2700), JPEG_QUALITY (95), MAX_BYTES (4000000), FORCE_JPEG (0).
set -euo pipefail

OWNER_REPO="jpcastillo-hub/vicasa-media-meta-assets"
BRANDS="wells farolazo presidente gran-ninot vivaldi zenka los-reyes cardenal castellana madrilena brisa guardatodo marsala-la-granja"
MAX_SIDE="${MAX_SIDE:-2700}"
JPEG_QUALITY="${JPEG_QUALITY:-95}"
MAX_BYTES="${MAX_BYTES:-4000000}"
FORCE_JPEG="${FORCE_JPEG:-0}"
export GIT_TERMINAL_PROMPT=0

die() { echo "ERROR: $*" >&2; exit 1; }

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"
git remote get-url origin | grep -q "$OWNER_REPO" || die "este clon no apunta a $OWNER_REPO"

rand() { uuidgen | tr 'A-Z' 'a-z'; }

cmd_push() {
  local src="${1:-}" brand="${2:-}"
  [ -f "$src" ] || die "no existe el archivo: $src"
  echo " $BRANDS " | grep -q " $brand " || die "marca no válida: '$brand'. Válidas: $BRANDS"

  WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT; local work="$WORK"
  local fmt w h bytes long ext out
  fmt="$(sips -g format "$src" | awk '/format:/{print $2}')"
  w="$(sips -g pixelWidth "$src" | awk '/pixelWidth:/{print $2}')"
  h="$(sips -g pixelHeight "$src" | awk '/pixelHeight:/{print $2}')"
  bytes="$(wc -c < "$src" | tr -d ' ')"
  long=$(( w > h ? w : h ))
  case "$fmt" in jpeg|png) ;; *) FORCE_JPEG=1 ;; esac

  # Siempre se trabaja sobre una copia; el original no se toca.
  if [ "$FORCE_JPEG" = "1" ] || [ "$long" -gt "$MAX_SIDE" ] || [ "$bytes" -gt "$MAX_BYTES" ]; then
    ext="jpg"; out="$work/art.jpg"
    if [ "$long" -gt "$MAX_SIDE" ]; then
      sips -s format jpeg -s formatOptions "$JPEG_QUALITY" -Z "$MAX_SIDE" "$src" --out "$out" >/dev/null
    else
      sips -s format jpeg -s formatOptions "$JPEG_QUALITY" "$src" --out "$out" >/dev/null
    fi
    echo "conversion=jpeg q$JPEG_QUALITY (origen ${fmt} ${w}x${h}, ${bytes} bytes)"
  else
    [ "$fmt" = "png" ] && ext="png" || ext="jpg"
    out="$work/art.$ext"; cp "$src" "$out"
    echo "conversion=ninguna (origen ${fmt} ${w}x${h}, ${bytes} bytes)"
  fi

  local id path branch blob t_brand t_root commit
  id="$(rand)"; path="$brand/$id.$ext"; branch="tmp-$(rand | cut -c1-12)"

  # Commit huérfano con un solo archivo: no toca main ni el árbol de trabajo.
  blob="$(git hash-object -w "$out")"
  t_brand="$(printf '100644 blob %s\t%s\n' "$blob" "$id.$ext" | git mktree)"
  t_root="$(printf '040000 tree %s\t%s\n' "$t_brand" "$brand" | git mktree)"
  commit="$(git -c user.name="vicasa-meta-upload" -c user.email="noreply@vicasa.com.gt" \
            commit-tree "$t_root" -m "tmp: arte en tránsito ($brand)")"
  git push -q origin "$commit:refs/heads/$branch" || die "push rechazado. PARAR y reportar; no rodear."

  local url="https://raw.githubusercontent.com/$OWNER_REPO/$branch/$path"
  local code="" ctype="" i
  for i in 1 2 3 4 5 6; do
    read -r code ctype < <(curl -sL -o /dev/null -w '%{http_code} %{content_type}\n' "$url") || true
    [ "$code" = "200" ] && break; sleep 3
  done

  echo "salida=$(sips -g pixelWidth -g pixelHeight "$out" | awk '/pixel/{printf "%s ", $2}')px, $(wc -c < "$out" | tr -d ' ') bytes"
  echo "sha256=$(shasum -a 256 "$out" | awk '{print $1}')"
  echo "branch=$branch"
  echo "path=$path"
  echo "http=$code"
  echo "content_type=$ctype"
  echo "raw_url=$url"
  case "$code $ctype" in
    "200 image/"*) echo "estado=OK" ;;
    *) echo "estado=FALLO (la URL no responde 200 image/*). Corré: $0 cleanup $branch" >&2; exit 2 ;;
  esac
}

cmd_cleanup() {
  local branch="${1:-}"
  case "$branch" in tmp-*) ;; *) die "solo se borran ramas temporales (tmp-*)" ;; esac
  git push -q origin --delete "$branch" || die "no se pudo borrar la rama $branch"
  echo "rama_borrada=$branch"
  echo "ramas_remotas=$(git ls-remote --heads origin | awk '{print $2}' | sed 's#refs/heads/##' | tr '\n' ' ')"
  echo "aviso=borrar la rama no limpia de inmediato el historial de Git; el archivo puede seguir accesible por SHA un tiempo"
}

cmd_list() { git ls-remote --heads origin | awk '{print $2}' | sed 's#refs/heads/##' | grep '^tmp-' || echo "(sin ramas temporales)"; }

case "${1:-}" in
  push) shift; cmd_push "$@" ;;
  cleanup) shift; cmd_cleanup "$@" ;;
  list) cmd_list ;;
  *) sed -n '2,9p' "$0"; exit 1 ;;
esac
