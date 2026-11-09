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

TESTDIR="$HOME/cloudphoto_test_upload"
EMPTYDIR="$HOME/cloudphoto_test_empty"
MISSINGDIR="$HOME/cloudphoto_test_does_not_exist"
ALBUM="test_upload_$$"

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

setup() {
    rm -rf "$TESTDIR" "$EMPTYDIR" "$MISSINGDIR"
    mkdir -p "$TESTDIR/nested" "$EMPTYDIR"
    echo test > "$TESTDIR/photo1.JPG"
    echo test > "$TESTDIR/photo2.jpeg"
    echo test > "$TESTDIR/Кириллица с пробелом.jpg"
    echo test > "$TESTDIR/readme.txt"
    echo test > "$TESTDIR/nested/ignored.jpg"
}

cleanup() {
    rm -rf "$TESTDIR" "$EMPTYDIR" "$MISSINGDIR"
    "$CLI" delete --album "$ALBUM" >/dev/null 2>&1 || true
}

trap cleanup EXIT

echo "== setup =="
setup
ls -la "$TESTDIR"
echo

echo "== 1. upload в новый альбом =="
"$CLI" upload --album "$ALBUM" --path "$TESTDIR"
check "upload (новый альбом)" 0 $?
echo "  альбомы:"
"$CLI" list | sed 's/^/    /'
echo "  фото в альбоме:"
"$CLI" list --album "$ALBUM" | sed 's/^/    /'
echo

echo "== 2. повторный upload (перезапись) =="
"$CLI" upload --album "$ALBUM" --path "$TESTDIR"
check "upload (перезапись)" 0 $?
echo "  фото в альбоме после перезаписи:"
"$CLI" list --album "$ALBUM" | sed 's/^/    /'
echo

echo "== 3. добавление новой фотографии =="
echo test > "$TESTDIR/photo3.jpg"
"$CLI" upload --album "$ALBUM" --path "$TESTDIR"
check "upload (новый файл)" 0 $?
echo "  фото в альбоме:"
"$CLI" list --album "$ALBUM" | sed 's/^/    /'
echo

echo "== 4. негативные сценарии =="
"$CLI" upload --album "$ALBUM" --path "$EMPTYDIR" >/dev/null 2>&1
check "пустой каталог" 1 $?

"$CLI" upload --album "$ALBUM" --path "$MISSINGDIR" >/dev/null 2>&1
check "несуществующий каталог" 1 $?

"$CLI" upload --path "$TESTDIR" >/dev/null 2>&1
check "без --album" 1 $?

"$CLI" upload --album "$ALBUM" --path "$TESTDIR" --extra foo >/dev/null 2>&1
check "лишний позиционный аргумент" 1 $?

"$CLI" upload --album "bad/album" --path "$TESTDIR" >/dev/null 2>&1
check "album с /" 1 $?
echo

echo "== итог =="
echo "PASS: $PASS, FAIL: $FAIL"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1 