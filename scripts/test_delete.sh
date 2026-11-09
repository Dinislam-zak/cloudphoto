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

SRCDIR="$HOME/cloudphoto_test_delete"
ALBUM="test_delete_$$"
ALBUM_EMPTY="test_delete_empty_$$"

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

list_has() {
    local desc="$1" needle="$2" listing="$3" want="$4"
    local found="no"
    echo "$listing" | grep -qxF -- "$needle" && found="yes"
    if [[ "$found" == "$want" ]]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc"
        FAIL=$((FAIL + 1))
    fi
}

cleanup() {
    rm -rf "$SRCDIR"
    "$CLI" delete --album "$ALBUM" >/dev/null 2>&1 || true
    "$CLI" delete --album "$ALBUM_EMPTY" >/dev/null 2>&1 || true
}

trap cleanup EXIT

echo "== setup =="
rm -rf "$SRCDIR"
mkdir -p "$SRCDIR"
echo p1 > "$SRCDIR/photo1.JPG"
echo p2 > "$SRCDIR/photo2.jpeg"
echo p3 > "$SRCDIR/Кириллица с пробелом.jpg"
"$CLI" upload --album "$ALBUM" --path "$SRCDIR" >/dev/null
"$CLI" list --album "$ALBUM" | sed 's/^/    /'
echo

echo "== 1. delete --photo (существующей) =="
"$CLI" delete --album "$ALBUM" --photo "photo1.JPG"
check "удаление photo1.JPG" 0 $?
listing=$("$CLI" list --album "$ALBUM")
list_has "photo1.JPG отсутствует" "photo1.JPG" "$listing" "no"
list_has "photo2.jpeg на месте" "photo2.jpeg" "$listing" "yes"
list_has "Кириллица с пробелом.jpg на месте" "Кириллица с пробелом.jpg" "$listing" "yes"
echo

echo "== 2. delete --photo (несуществующей) =="
"$CLI" delete --album "$ALBUM" --photo "no_such.jpg" >/dev/null 2>&1
check "несуществующая фотография" 1 $?
echo

echo "== 3. delete без --photo =="
"$CLI" delete --album "$ALBUM"
check "удаление всего альбома" 0 $?
listing=$("$CLI" list)
list_has "альбом $ALBUM исчез" "$ALBUM" "$listing" "no"
echo

echo "== 4. delete несуществующего альбома =="
"$CLI" delete --album "$ALBUM" >/dev/null 2>&1
check "несуществующий альбом" 1 $?
echo

echo "== 5. пустой альбом =="
mkdir -p "$SRCDIR/empty"
echo p > "$SRCDIR/empty/x.jpg"
"$CLI" upload --album "$ALBUM_EMPTY" --path "$SRCDIR/empty" >/dev/null
"$CLI" delete --album "$ALBUM_EMPTY" --photo "x.jpg" >/dev/null
check "delete --photo последней фотографии" 0 $?
listing=$("$CLI" list)
list_has "пустой альбом остался" "$ALBUM_EMPTY" "$listing" "yes"
"$CLI" delete --album "$ALBUM_EMPTY"
check "удаление пустого альбома" 0 $?
listing=$("$CLI" list)
list_has "пустой альбом удалён" "$ALBUM_EMPTY" "$listing" "no"
echo

echo "== 6. delete без --album =="
"$CLI" delete >/dev/null 2>&1
check "без --album" 1 $?

"$CLI" delete --album "bad/album" >/dev/null 2>&1
check "album с /" 1 $?

"$CLI" delete --album "$ALBUM" --photo "bad/photo" >/dev/null 2>&1
check "photo с /" 1 $?

"$CLI" delete --album "$ALBUM" --extra foo >/dev/null 2>&1
check "лишний позиционный аргумент" 1 $?
echo

echo "== итог =="
echo "PASS: $PASS, FAIL: $FAIL"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1