#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

: "${BUCKET:?BUCKET не задан}"
: "${AWS_ACCESS_KEY_ID:?AWS_ACCESS_KEY_ID не задан}"
: "${AWS_SECRET_ACCESS_KEY:?AWS_SECRET_ACCESS_KEY не задан}"

CLI="$PROJECT_DIR/cloudphoto"
if [[ ! -x "$CLI" ]]; then
    echo "Сначала соберите: (cd \"$PROJECT_DIR\" && go build -o cloudphoto ./cmd/cloudphoto)" >&2
    exit 1
fi

SRCDIR="$HOME/cloudphoto_test_download_src"
DSTDIR="$HOME/cloudphoto_test_download_dst"
MISSINGDIR="$HOME/cloudphoto_test_download_missing"
ALBUM="test_download_$$"

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

check_diff() {
    local desc="$1" f1="$2" f2="$3"
    if diff -q "$f1" "$f2" >/dev/null 2>&1; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc"
        FAIL=$((FAIL + 1))
    fi
}

cleanup() {
    rm -rf "$SRCDIR" "$DSTDIR" "$MISSINGDIR"
    "$CLI" delete --album "$ALBUM" >/dev/null 2>&1 || true
}

trap cleanup EXIT

echo "== setup =="
rm -rf "$SRCDIR" "$DSTDIR" "$MISSINGDIR"
mkdir -p "$SRCDIR" "$DSTDIR"
echo "content-photo1" > "$SRCDIR/photo1.JPG"
echo "content-photo2" > "$SRCDIR/photo2.jpeg"
echo "content-кириллица" > "$SRCDIR/Кириллица с пробелом.jpg"
"$CLI" upload --album "$ALBUM" --path "$SRCDIR" >/dev/null
echo

echo "== 1. download в пустой каталог =="
"$CLI" download --album "$ALBUM" --path "$DSTDIR"
check "download в пустой каталог" 0 $?
echo "  содержимое DSTDIR:"
ls -la "$DSTDIR" | sed 's/^/    /'
echo

echo "== 2. проверка содержимого =="
check_diff "photo1.JPG совпадает" "$SRCDIR/photo1.JPG" "$DSTDIR/photo1.JPG"
check_diff "photo2.jpeg совпадает" "$SRCDIR/photo2.jpeg" "$DSTDIR/photo2.jpeg"
check_diff "Кириллица с пробелом.jpg совпадает" "$SRCDIR/Кириллица с пробелом.jpg" "$DSTDIR/Кириллица с пробелом.jpg"
echo

echo "== 3. повторный download (перезапись) =="
echo "modified" > "$DSTDIR/photo1.JPG"
"$CLI" download --album "$ALBUM" --path "$DSTDIR"
check "download (перезапись)" 0 $?
check_diff "photo1.JPG перезаписан" "$SRCDIR/photo1.JPG" "$DSTDIR/photo1.JPG"
echo

echo "== 4. негативные сценарии =="
"$CLI" download --album "$ALBUM" --path "$MISSINGDIR" >/dev/null 2>&1
check "несуществующий каталог" 1 $?

"$CLI" download --album "no_such_album_$$" --path "$DSTDIR" >/dev/null 2>&1
check "несуществующий альбом" 1 $?

"$CLI" download --path "$DSTDIR" >/dev/null 2>&1
check "без --album" 1 $?

"$CLI" download --album "$ALBUM" --path "$DSTDIR" --extra foo >/dev/null 2>&1
check "лишний позиционный аргумент" 1 $?
echo

echo "== итог =="
echo "PASS: $PASS, FAIL: $FAIL"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1