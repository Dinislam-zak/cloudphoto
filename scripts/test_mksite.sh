#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

: "${BUCKET:?BUCKET не задан}"
: "${AWS_ACCESS_KEY_ID:?AWS_ACCESS_KEY_ID не задан}"
: "${AWS_SECRET_ACCESS_KEY:?AWS_SECRET_ACCESS_KEY не задан}"

CLI="$PROJECT_DIR/cloudphoto"
STORAGE_URL="https://storage.yandexcloud.net/$BUCKET"
SITE_URL="${SITE_URL:-https://photos.vvot16.itiscl.ru}"

if [[ ! -x "$CLI" ]]; then
    echo "Сначала соберите: (cd \"$PROJECT_DIR\" && go build -o cloudphoto ./cmd/cloudphoto)" >&2
    exit 1
fi

SRCDIR="$HOME/cloudphoto_test_mksite"
ALBUM_A="test_mksite_alpha_$$"
ALBUM_B="test_mksite_beta_$$"

PASS=0
FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo "  PASS: $desc (exit=$actual)"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (expected exit=$expected, got exit=$actual)"
        FAIL=$((FAIL + 1))
    fi
}

page_has() {
    local desc="$1" url="$2" needle="$3"
    local body
    body=$(curl -sS "$url")
    if echo "$body" | grep -qF -- "$needle"; then
        echo "  PASS: $desc (содержит '$needle')"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (не содержит '$needle')"
        echo "    URL: $url"
        echo "    первые 200 байт:"
        echo "$body" | head -c 200 | sed 's/^/      /'
        echo
        FAIL=$((FAIL + 1))
    fi
}

cleanup() {
    rm -rf "$SRCDIR"
    "$CLI" delete --album "$ALBUM_A" >/dev/null 2>&1 || true
    "$CLI" delete --album "$ALBUM_B" >/dev/null 2>&1 || true
    for a in $("$CLI" list 2>/dev/null); do
        case "$a" in
            test_*) "$CLI" delete --album "$a" >/dev/null 2>&1 || true ;;
        esac
    done
}

trap cleanup EXIT

echo "== setup =="
rm -rf "$SRCDIR"
mkdir -p "$SRCDIR"
echo p1 > "$SRCDIR/photo1.JPG"
echo p2 > "$SRCDIR/Кириллица с пробелом.jpg"
"$CLI" upload --album "$ALBUM_A" --path "$SRCDIR" >/dev/null

mkdir -p "$SRCDIR/empty"
echo tmp > "$SRCDIR/empty/tmp.jpg"
"$CLI" upload --album "$ALBUM_B" --path "$SRCDIR/empty" >/dev/null
"$CLI" delete --album "$ALBUM_B" --photo "tmp.jpg" >/dev/null
echo "  альбомы до mksite:"
"$CLI" list | sed 's/^/    /'
echo

echo "== 1. mksite =="
"$CLI" mksite
check "mksite" 0 $?
echo

echo "== 2. проверка index.html через storage endpoint =="
page_has "index содержит заголовок" "$STORAGE_URL/index.html" "Фотоархив"
page_has "index содержит альбом A" "$STORAGE_URL/index.html" "$ALBUM_A"
page_has "index содержит альбом B" "$STORAGE_URL/index.html" "$ALBUM_B"
echo

echo "== 3. проверка error.html =="
page_has "error содержит заголовок" "$STORAGE_URL/error.html" "Ошибка"
page_has "error содержит ссылку на главную" "$STORAGE_URL/error.html" 'href="index.html"'
echo

echo "== 4. проверка страниц альбомов =="
albums=($("$CLI" list))
found_a="no"
found_b="no"
for i in "${!albums[@]}"; do
    n=$((i + 1))
    a="${albums[$i]}"
    if [[ "$a" == "$ALBUM_A" ]]; then
        found_a="yes"
        page_has "album${n}.html содержит имя A" "$STORAGE_URL/album${n}.html" "$ALBUM_A"
        page_has "album${n}.html содержит galleria" "$STORAGE_URL/album${n}.html" 'class="galleria"'
        page_has "album${n}.html содержит photo1.JPG" "$STORAGE_URL/album${n}.html" "photo1.JPG"
        page_has "album${n}.html содержит Кириллица с пробелом.jpg" "$STORAGE_URL/album${n}.html" "Кириллица с пробелом.jpg"
    fi
    if [[ "$a" == "$ALBUM_B" ]]; then
        found_b="yes"
        page_has "album${n}.html (пустой) содержит имя B" "$STORAGE_URL/album${n}.html" "$ALBUM_B"
        page_has "album${n}.html (пустой) содержит 'Фотоальбом пустой'" "$STORAGE_URL/album${n}.html" "Фотоальбом пустой."
    fi
done
[[ "$found_a" == "yes" ]] && { echo "  PASS: страница для альбома A найдена"; PASS=$((PASS + 1)); } || { echo "  FAIL: страница для альбома A не найдена"; FAIL=$((FAIL + 1)); }
[[ "$found_b" == "yes" ]] && { echo "  PASS: страница для альбома B найдена"; PASS=$((PASS + 1)); } || { echo "  FAIL: страница для альбома B не найдена"; FAIL=$((FAIL + 1)); }
echo

echo "== 5. проверка URL-кодирования фото =="
# Проверим, что в HTML действительно закодирован кириллический файл
body=$(curl -sS "$STORAGE_URL/album1.html")
if echo "$body" | grep -qE 'data-title="Кириллица с пробелом\.jpg"'; then
    echo "  PASS: имя в data-title не закодировано (правильно, это HTML-атрибут)"
    PASS=$((PASS + 1))
else
    echo "  FAIL: имя в data-title не найдено как ожидалось"
    FAIL=$((FAIL + 1))
fi
if echo "$body" | grep -qE 'src="/album/[^"]*%D0%9A[^"]*"'; then
    echo "  PASS: URL фото закодирован в UTF-8 percent-encoding (%D0%9A = К)"
    PASS=$((PASS + 1))
else
    echo "  WARN: URL фото не в percent-encoding или фото в другом альбоме"
fi
echo

echo "== 6. проверка сайта через домен (может упасть, если TLS ещё не разложился) =="
if curl -sfI --max-time 10 "$SITE_URL/index.html" >/dev/null 2>&1; then
    echo "  PASS: $SITE_URL/index.html доступен через HTTPS"
    PASS=$((PASS + 1))
else
    echo "  SKIP: $SITE_URL пока недоступен (TLS/website propagation)"
    echo "        Попробуйте позже: curl -vI $SITE_URL/index.html"
fi
echo

echo "== 7. негативные сценарии =="
"$CLI" mksite --extra foo >/dev/null 2>&1
check "mksite с лишним аргументом" 1 $?
echo

echo "== итог =="
echo "PASS: $PASS, FAIL: $FAIL"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1