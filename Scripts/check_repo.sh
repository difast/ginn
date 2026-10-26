#!/usr/bin/env bash
# Проверка структуры UE-проекта INTGames в Git (запуск из корня репозитория в Git Bash):
#   bash Scripts/check_repo.sh
# Проверяет файлы в индексе Git (закоммиченные + добавленные через git add),
# поэтому полезно запускать после `git add` и перед `git commit`.
# Код выхода: 0 — ошибок нет (предупреждения допустимы), 1 — есть ошибки.

set -u

FAILS=0
WARNS=0
pass() { printf '  [OK]   %s\n' "$1"; }
warn() { printf '  [WARN] %s\n' "$1"; WARNS=$((WARNS + 1)); }
fail() { printf '  [FAIL] %s\n' "$1"; FAILS=$((FAILS + 1)); }

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "Не git-репозиторий"; exit 1; }
cd "$ROOT" || exit 1

LFS_POINTER_MAX_BYTES=1024
LARGE_FILE_BYTES=$((50 * 1024 * 1024))
LFS_FREE_QUOTA_BYTES=$((1024 * 1024 * 1024))

echo "== Git и LFS"
if git lfs version >/dev/null 2>&1; then
    pass "git-lfs установлен ($(git lfs version | head -n1))"
else
    fail "git-lfs не установлен: https://git-lfs.com, затем 'git lfs install'"
fi
if grep -qs "git lfs" "$(git rev-parse --git-path hooks)/pre-push"; then
    pass "LFS-хуки установлены в репозиторий"
else
    fail "LFS-хуки не установлены: выполните 'git lfs install'"
fi
if git remote get-url origin 2>/dev/null | grep -q "difast/ginn"; then
    pass "origin → $(git remote get-url origin)"
else
    warn "origin не указывает на difast/ginn"
fi

echo "== Файлы проекта"
for f in CLAUDE.md docs/ARCHITECTURE.md .gitignore .gitattributes; do
    if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then pass "$f в Git"; else fail "$f отсутствует в индексе Git"; fi
done

shopt -s nullglob
UPROJECTS=( *.uproject )
shopt -u nullglob
if [ "${#UPROJECTS[@]}" -eq 1 ]; then
    UPROJECT=${UPROJECTS[0]}
    MODULE=${UPROJECT%.uproject}
    pass "$UPROJECT найден в корне"
    git ls-files --error-unmatch "$UPROJECT" >/dev/null 2>&1 || fail "$UPROJECT не добавлен в Git"
    ENGINE=$(grep -o '"EngineAssociation"[^,]*' "$UPROJECT" | sed 's/.*: *"\(.*\)"/\1/')
    if [ -n "$ENGINE" ]; then pass "EngineAssociation = $ENGINE"; else warn "EngineAssociation не задан в $UPROJECT"; fi
    for f in "Source/$MODULE.Target.cs" "Source/${MODULE}Editor.Target.cs" "Source/$MODULE/$MODULE.Build.cs"; do
        if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then pass "$f"; else fail "$f отсутствует в Git"; fi
    done
else
    fail "в корне должен быть ровно один .uproject (найдено: ${#UPROJECTS[@]})"
fi

for d in Config Content Source; do
    n=$(git ls-files -- "$d" | wc -l)
    if [ "$n" -gt 0 ]; then pass "$d/: файлов в Git — $n"; else fail "$d/: нет файлов в Git"; fi
done
git ls-files --error-unmatch Config/DefaultEngine.ini >/dev/null 2>&1 || fail "Config/DefaultEngine.ini отсутствует в Git"

echo "== Лишнее в Git"
BAD=$(git ls-files | grep -E '(^|/)(Binaries|Intermediate|Saved|DerivedDataCache|\.vs|\.idea)/|\.(sln|suo|pdb|VC\.db)$' || true)
if [ -z "$BAD" ]; then
    pass "нет Binaries/Intermediate/Saved/DerivedDataCache/.vs/*.sln"
else
    fail "в Git попали генерируемые файлы ($(echo "$BAD" | wc -l)), первые:"
    echo "$BAD" | head -n 10 | sed 's/^/           /'
    echo "         убрать из индекса (файлы на диске останутся): git rm -r --cached <путь>"
fi

UNTRACKED=$(git ls-files --others --exclude-standard -- Config Content Source Plugins ./*.uproject 2>/dev/null || true)
if [ -z "$UNTRACKED" ]; then
    pass "все файлы Config/Content/Source/Plugins добавлены"
else
    warn "не добавлены в Git ($(echo "$UNTRACKED" | wc -l)), первые:"
    echo "$UNTRACKED" | head -n 10 | sed 's/^/           /'
fi

echo "== LFS-указатели"
# Размер объекта в индексе: LFS-указатель весит ~130 байт, настоящий ассет — килобайты и больше.
NOT_LFS=0
LFS_BYTES=0
while IFS=$'\t' read -r size path; do
    attr=$(git check-attr filter -- "$path" | sed 's/.*: filter: //')
    if [ "$attr" = "lfs" ]; then
        if [ "$size" -gt "$LFS_POINTER_MAX_BYTES" ]; then
            [ "$NOT_LFS" -lt 10 ] && echo "           не LFS-указатель: $path ($size байт)"
            NOT_LFS=$((NOT_LFS + 1))
        elif [ -f "$path" ]; then
            LFS_BYTES=$((LFS_BYTES + $(wc -c < "$path")))
        fi
    elif [ "$size" -gt "$LARGE_FILE_BYTES" ]; then
        warn "крупный файл вне LFS: $path ($((size / 1024 / 1024)) МБ) — добавьте расширение в .gitattributes"
    fi
done < <(git ls-files -s | awk '{print $2}' | git cat-file --batch-check='%(objectsize)' \
         | paste - <(git ls-files -s | cut -f2-))
if [ "$NOT_LFS" -eq 0 ]; then
    pass "все бинарные ассеты хранятся как LFS-указатели"
else
    fail "$NOT_LFS файл(ов) с LFS-расширением добавлены в Git напрямую."
    echo "         исправить: git rm -r --cached <пути> && git add <пути>  (после 'git lfs install')"
fi
LFS_MB=$((LFS_BYTES / 1024 / 1024))
if [ "$LFS_BYTES" -gt "$LFS_FREE_QUOTA_BYTES" ]; then
    warn "объём LFS ≈ ${LFS_MB} МБ — больше бесплатной квоты GitHub LFS (1 ГБ)"
else
    pass "объём LFS-файлов ≈ ${LFS_MB} МБ (бесплатная квота GitHub — 1 ГБ хранения)"
fi

echo
echo "Итог: ошибок — $FAILS, предупреждений — $WARNS"
[ "$FAILS" -eq 0 ]
