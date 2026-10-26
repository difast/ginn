# Подключение локального проекта INTGames к репозиторию `difast/ginn`

Вариант А: проект создан в редакторе из шаблона **First Person (C++)**, затем подключается к
существующему репозиторию. Файлы репозитория (`CLAUDE.md`, `docs/`, `Scripts/`, `.gitignore`,
`.gitattributes`) сохраняются, история Git не переписывается, force-push не нужен.

Все команды — в **Git Bash** (входит в Git for Windows).

## 0. Что нужно установить

- Unreal Engine 5 (через Epic Games Launcher) — запомните точную версию (например, 5.6).
- Visual Studio 2022 с нагрузкой **«Разработка игр на C++»** (Game development with C++) и Windows SDK.
- Git for Windows (включает Git LFS). Проверка: `git --version` и `git lfs version`.
- Доступ на запись в `github.com/difast/ginn`.

## 1. Создать проект

1. Unreal Project Browser → **Games** → **First Person**.
2. Project Defaults: **C++**, Target Platform: **Desktop**, Quality: **Maximum**,
   **Starter Content: выключить** — экономит место в LFS (бесплатно на GitHub — 1 ГБ).
3. Project Name: **`INTGames`**, папка например `D:/Projects` → получится `D:/Projects/INTGames`.
   Путь без кириллицы и пробелов.
4. Дождаться компиляции и открытия редактора, нажать **Play**, убедиться, что персонаж ходит и
   стреляет. Закрыть редактор и Visual Studio.

## 2. Резервная копия

Скопируйте папку `D:/Projects/INTGames` целиком (например, в `D:/Backup/INTGames_template`).
Это страховка на любой случай ниже.

## 3. Подключить репозиторий (без перезаписи файлов)

```bash
cd /d/Projects/INTGames
git status
```

- **`fatal: not a git repository`** — нормальный случай, продолжайте с шага 3а.
- **Репозиторий уже есть** (его могли создать Rider/VS или галочка в редакторе) — шаг 3б.

### 3а. Обычный случай

```bash
git init -b main
git lfs install                       # LFS-хуки — ДО первого git add
git remote add origin https://github.com/difast/ginn.git
git fetch origin
git switch -c main --track origin/main
```

`git switch` выкладывает файлы репозитория рядом с файлами проекта. Если в папке уже есть файл с
тем же именем (например, свой `.gitignore`), Git **ничего не перезапишет** и остановится с
сообщением `untracked working tree files would be overwritten`. Тогда переименуйте свой файл
(`mv .gitignore .gitignore.local`), повторите `git switch …` и сообщите мне — сравним содержимое.

Проверка: `ls CLAUDE.md docs/ARCHITECTURE.md .gitattributes` — файлы на месте; `git log --oneline`
показывает коммиты из GitHub.

### 3б. В папке уже есть репозиторий с коммитами

Истории объединяются merge-коммитом, ничего не переписывается:

```bash
git lfs install
git remote add origin https://github.com/difast/ginn.git   # если origin ещё нет
git fetch origin
git merge origin/main --allow-unrelated-histories
```

Если merge сообщит о конфликте — остановитесь и пришлите мне вывод `git status`.
Если ассеты уже были закоммичены без LFS, скрипт проверки (шаг 4) покажет это — не пушьте, напишите мне.

## 4. Добавить проект и проверить структуру

```bash
git add .
git status --short | head -n 40       # просмотреть, что добавляется
bash Scripts/check_repo.sh            # должно быть: «ошибок — 0»
```

`Scripts/check_repo.sh` проверяет: LFS установлен и хуки активны, есть `.uproject` и
`EngineAssociation`, есть `Target.cs` / `Build.cs`, в индекс не попали `Binaries/`,
`Intermediate/`, `Saved/`, `DerivedDataCache/`, `.vs/`, `*.sln`, все `.uasset`/`.umap` сохранены как
LFS-указатели, оценивает объём LFS. При `[FAIL]` скрипт печатает команду исправления.

Если всё в порядке:

```bash
git commit -m "Add INTGames project from UE First Person C++ template"
git push origin main
```

Обычный push — **не** `--force`. Если push отклонён (`rejected … fetch first`), выполните
`git pull --no-rebase origin main` и повторите push.

## 5. Что должно попасть в Git

| Путь | Что это |
|---|---|
| `INTGames.uproject` | описание проекта, версия движка, плагины |
| `.vsconfig` | список компонентов Visual Studio (генерирует UE) |
| `Config/*.ini` | `DefaultEngine.ini`, `DefaultGame.ini`, `DefaultInput.ini`, `DefaultEditor.ini` и др. |
| `Source/INTGames.Target.cs`, `Source/INTGamesEditor.Target.cs` | таргеты сборки |
| `Source/INTGames/**` | `INTGames.Build.cs`, `.h`, `.cpp` шаблона |
| `Content/**` | все `.uasset` и `.umap` шаблона — **через LFS** |
| `Plugins/**` | исходники и `.uplugin` (если появятся), без `Binaries/` и `Intermediate/` |
| `CLAUDE.md`, `docs/`, `Scripts/`, `.gitignore`, `.gitattributes` | уже в репозитории |

**Не должно попасть:** `Binaries/`, `Intermediate/`, `Saved/`, `DerivedDataCache/`, `.vs/`,
`.idea/`, `*.sln`, `*.pdb`, `Packaged/`. Всё это генерируется заново.

## 6. Финальная проверка: чистый клон

Это единственный способ убедиться, что в Git есть всё необходимое.

```bash
cd /d/Projects
git clone https://github.com/difast/ginn.git INTGames_clonetest
cd INTGames_clonetest
git lfs pull
bash Scripts/check_repo.sh
```

Затем в Проводнике: ПКМ по `INTGames.uproject` → **Generate Visual Studio project files**, открыть
`INTGames.uproject` (согласиться на сборку модулей) → редактор открывается, карта шаблона
загружается, **Play** работает. После проверки папку `INTGames_clonetest` можно удалить.

На GitHub у любого `.uasset` должна быть пометка **«Stored with Git LFS»**.

## 7. Что прислать мне после подключения

1. Вывод `bash Scripts/check_repo.sh`.
2. Версию UE (`EngineAssociation` из `.uproject`).
3. Подтверждение: проект собирается, редактор открывается, PIE работает (в том числе на чистом клоне).
4. Если были ошибки сборки — кусок лога из `Saved/Logs/INTGames.log` или окна Output в VS.
