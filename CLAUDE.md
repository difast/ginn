# CLAUDE.md — правила разработки INT Games

Одиночный сюжетный шутер от первого лица на Unreal Engine 5, платформа — Windows (Win64).
Ближайшая цель: играбельная миссия на 10–15 минут. Архитектура и этапы описаны в
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md), статус этапов ведётся там же.

## Проект

| Параметр | Значение |
|---|---|
| Движок | Unreal Engine 5 — **точная версия уточняется** (зафиксировать в `.uproject` → `EngineAssociation`) |
| C++ модуль | `INTGames` (`Source/INTGames`) |
| Основа | шаблон First Person (C++); подключение — [`docs/SETUP.md`](docs/SETUP.md) |
| Префикс классов | новые классы — `Int` (`UIntHealthComponent`, `FIntAmmoState`); классы шаблона (`AINTGamesCharacter` и т.п.) сохраняют свои имена |
| Префикс ассетов | стандарт UE: `BP_`, `WBP_`, `DA_`, `IA_`, `IMC_`, `BT_`, `BB_`, `M_`, `MI_`, `SM_`, `SK_`, `ABP_`, `L_` |
| Папка контента игры | `Content/INTGames/...` (сторонние паки — в своих папках, не смешивать) |

## Главные правила

1. **Не удалять существующие файлы и не заменять работающие системы** без явной необходимости
   и без согласования. Расширять — наследованием, компонентами, новыми классами.
2. **Маленькие проверяемые этапы.** Один этап = одна механика + способ проверки. Не начинать
   следующий этап, пока текущий не проверен.
3. **Честность о проверке.** Никогда не писать «собралось» или «тесты прошли», если сборка/тесты
   реально не запускались. В отчёте явно разделять: *запущено и прошло* / *запущено и упало* /
   *не запускалось (почему)*.
4. **Бинарные ассеты (`.uasset`, `.umap`) редактирует только человек в редакторе.** Агент без
   редактора их не создаёт и не правит; вместо этого пишет точную инструкцию, какой ассет
   создать, от какого класса наследовать и какие свойства выставить.

## Разделение C++ / Blueprints

**C++** — ядро и всё, что содержит логику и состояние:
- компоненты (здоровье, оружие), базовые классы персонажей, контроллеров, GameMode;
- система миссий (стадии, цели, переходы, события);
- AI: контроллер, восприятие, задачи/сервисы Behavior Tree;
- базовые классы виджетов (`UUserWidget` с `BindWidget`) — данные и события.

**Blueprints / Data Assets** — настройка и контент:
- наследники C++ классов (`BP_PlayerCharacter`, `BP_Enemy_Grunt`, `BP_Weapon_Rifle`) — меши, звуки, FX, числа;
- `DA_` ассеты оружия и миссий — баланс и сценарий без перекомпиляции;
- `BT_`/`BB_` деревья поведения, `WBP_` вёрстка UI, скриптовые события уровня.

Правило: если в Blueprint появляется логика сложнее «вызвать функцию / выставить значение / проиграть
эффект» — она переносится в C++ и выставляется как `BlueprintCallable`/`BlueprintImplementableEvent`.

## Стиль C++

- Следовать [Epic C++ Coding Standard](https://dev.epicgames.com/documentation/en-us/unreal-engine/epic-cplusplus-coding-standard-for-unreal-engine).
- `TObjectPtr<>` для UPROPERTY-указателей, `TWeakObjectPtr<>` для невладеющих ссылок вне UPROPERTY.
- Настраиваемые значения — `UPROPERTY(EditDefaultsOnly/EditAnywhere, Category="INT|...")`
  с `ClampMin`, а не магические числа в коде.
- События наружу — `DECLARE_DYNAMIC_MULTICAST_DELEGATE_*` (`OnHealthChanged`, `OnAmmoChanged`,
  `OnObjectiveUpdated`), UI и BP подписываются на них, а не опрашивают в Tick.
- Без `Tick`, если можно обойтись таймерами/событиями. `PrimaryComponentTick.bCanEverTick = false` по умолчанию.
- Урон — через стандартный пайплайн UE (`UGameplayStatics::ApplyPointDamage` → `OnTakeAnyDamage`),
  чтобы игрок, враги и разрушаемые объекты работали одинаково.
- Логика, которую можно тестировать без мира (боезапас, здоровье, машина состояний миссии),
  выносится в чистые функции/структуры (`FIntAmmoState`), чтобы покрываться автотестами.
- Логирование — собственная категория `LogINT` (`UE_LOG(LogINT, ...)`), без `GEngine->AddOnScreenDebugMessage` в финальном коде.
- Include-What-You-Use, forward declarations в заголовках, `.generated.h` — последним include.
- Сетевая игра не планируется: репликацию не добавлять, но и не делать ничего, что её принципиально ломает.

## Структура исходников

```
Source/INTGames/
  Public/  Private/            — зеркальная структура
    Core/                      — GameMode, PlayerController, лог-категория
    Player/                    — персонаж игрока
    Components/                — HealthComponent и т.п. (общие для игрока и врагов)
    Weapons/                   — оружие, данные оружия, состояние боезапаса
    AI/                        — враг, AIController, задачи BT
    Mission/                   — подсистема миссии, цели, триггеры
    UI/                        — базовые классы виджетов
  Private/Tests/               — автотесты (только под WITH_DEV_AUTOMATION_TESTS)
```

## Сборка и проверка

Unreal Engine есть только на Windows-машине разработчика. В облачном окружении агента движка нет —
там возможна только статическая проверка (чтение кода, ревью), **не компиляция**.

```bat
:: Сборка редакторского таргета
"<UE>\Engine\Build\BatchFiles\Build.bat" INTGamesEditor Win64 Development -Project="%CD%\INTGames.uproject" -WaitMutex

:: Автотесты (headless)
"<UE>\Engine\Binaries\Win64\UnrealEditor-Cmd.exe" "%CD%\INTGames.uproject" -ExecCmds="Automation RunTests INTGames; Quit" -unattended -nopause -nullrhi -log

:: Сборка игры
"<UE>\Engine\Build\BatchFiles\RunUAT.bat" BuildCookRun -project="%CD%\INTGames.uproject" -platform=Win64 -clientconfig=Development -build -cook -stage -pak -archive -archivedirectory="%CD%\Packaged"
```

Каждый этап в `docs/ARCHITECTURE.md` содержит: что проверяется автотестом, что — вручную в PIE
(Play In Editor) по чек-листу.

## Git

- Основная ветка — `main`. История не переписывается: без `--force`, `rebase` опубликованных коммитов, `amend` после push.
- Бинарные ассеты — через **Git LFS** (`.gitattributes`). Не коммитить `Binaries/`, `Intermediate/`,
  `Saved/`, `DerivedDataCache/`, `.vs/`, `*.sln` (см. `.gitignore`).
- Перед коммитом с ассетами — `bash Scripts/check_repo.sh` (ошибок быть не должно).
- `.uasset`/`.umap` нельзя мёрджить — перед правкой общего ассета договориться (или LFS lock).
- Коммиты небольшие, по одному логическому изменению, сообщение — что и зачем.
