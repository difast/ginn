# INT Games — архитектура и план первой версии

## 0. Исходное состояние (аудит от 2026-10-26)

| Что проверено | Результат |
|---|---|
| Коммиты / ветки в `difast/ginn` | нет, репозиторий пустой |
| `.uproject`, версия движка | отсутствует, версия не определена |
| C++ классы (`Source/`) | нет |
| Blueprints, карты, ассеты (`Content/`) | нет |
| Конфиги (`Config/`) | нет |
| Unreal Engine в облачном окружении агента | не установлен, компиляция там невозможна |

**Реализованные механики: ни одной.** Все пункты первой версии нужно делать с нуля.

## 1. Цель первой версии (Vertical Slice)

Одна миссия на 10–15 минут: игрок проходит 3–5 стадий задания (дойти, зачистить, взаимодействовать,
выжить/эвакуироваться), сражается с базовыми противниками и видит экран завершения.

## 2. Архитектура

```
AIntGameMode ──────── держит ссылку на UIntMissionData (DA_Mission_01)
   │                  обрабатывает смерть игрока → провал/рестарт
   ▼
UIntMissionSubsystem (UWorldSubsystem) — машина состояний миссии
   │  Stages[i] → Objectives[] (все выполнены → следующая стадия)
   │  события: OnStageStarted / OnObjectiveUpdated / OnMissionCompleted / OnMissionFailed
   │  получает сигналы: OnActorKilled(Tags), OnTriggerEntered(Id), OnInteracted(Id)
   ▼
UIntMissionObjective (UObject, EditInlineNew, Blueprintable, abstract)
   ├─ UIntObjective_KillTargets   — убить N акторов с GameplayTag
   ├─ UIntObjective_ReachLocation — войти в AIntObjectiveTrigger с Id
   ├─ UIntObjective_Interact      — использовать AIntInteractable с Id
   └─ BP-наследники для особых случаев (таймер, скриптовая сцена)

AIntPlayerController ── Enhanced Input контекст, HUD, экраны завершения/смерти
AIntPlayerCharacter (ACharacter)
   ├─ UCameraComponent + руки (USkeletalMeshComponent, только владельцу)
   ├─ UIntHealthComponent  ◄── общий для игрока и врагов
   └─ AIntWeapon (прикреплён к рукам)
          ├─ UIntWeaponData (DA_): урон, темп, магазин, запас, время перезарядки, разброс, дальность, FX
          └─ FIntAmmoState — чистая логика боезапаса (тестируется без мира)

AIntEnemyCharacter (ACharacter)
   ├─ UIntHealthComponent, AIntWeapon, GameplayTags (для целей миссии)
   └─ AIntEnemyAIController
          ├─ UAIPerceptionComponent (зрение + реакция на урон)
          └─ BT_Enemy / BB_Enemy: Idle/Patrol → Combat (сблизиться, стрелять) → Search
             C++ задачи: UBTTask_IntFireWeapon, UBTTask_IntReload; сервис UBTService_IntUpdateTarget
UI (C++ база + WBP вёрстка):
   UIntHUDWidget (здоровье, патроны, текущая цель, прицел) · UIntMissionEndWidget (итог, статистика, «заново/выход»)
```

Ключевые решения:
- **Урон** — стандартный `ApplyPointDamage` / `OnTakeAnyDamage`: один путь для игрока, врагов, объектов.
- **Стрельба** — hitscan (line trace по своему каналу `Weapon` в `DefaultEngine.ini`). Снаряды — позже, при необходимости.
- **ИИ** — Behavior Tree + AI Perception (зрелый и документированный путь; StateTree можно рассмотреть позже).
- **Миссия** — данные в `UIntMissionData`, логика в подсистеме; связь с уровнем через GameplayTags и Id
  триггеров, без жёстких ссылок на акторы уровня из C++.
- **Сохранения/чекпоинты** — вне первой версии; при смерти — рестарт уровня (позже — с начала стадии).

## 3. Этапы

Каждый этап заканчивается сборкой на Windows и проверкой. Статус: ⬜ не начат · 🟨 в работе · ✅ проверен.

### Этап 0 — Документация ✅ (этот коммит)
`CLAUDE.md`, `docs/ARCHITECTURE.md`. Проверка: ревью человеком.

### Этап 1 — Каркас проекта и управление от первого лица ⬜
Файлы (новые):
- `.gitignore`, `.gitattributes` (LFS для `*.uasset`, `*.umap`, текстур/звука)
- `INTGames.uproject` (плагины: EnhancedInput, GameplayTags; позже AI-модули)
- `Source/INTGames.Target.cs`, `Source/INTGamesEditor.Target.cs`
- `Source/INTGames/INTGames.Build.cs`, `INTGames.h/.cpp` (модуль, `LogINT`)
- `Config/DefaultEngine.ini`, `DefaultGame.ini`, `DefaultInput.ini` (Enhanced Input по умолчанию)
- `Public|Private/Core/IntGameMode.*`, `Core/IntPlayerController.*`
- `Public|Private/Player/IntPlayerCharacter.*` — камера, руки, ходьба/бег/прыжок/приседание, обзор мышью;
  все Input Action / Mapping Context — UPROPERTY-слоты.

Работа в редакторе (человек): создать `IA_Move`, `IA_Look`, `IA_Jump`, `IA_Crouch`, `IA_Sprint`,
`IMC_Default`, `BP_PlayerCharacter`, `BP_GameMode`, тестовую карту `L_Dev_Movement` — по инструкции из отчёта этапа.

Проверка:
- сборка `INTGamesEditor Win64 Development` без ошибок и предупреждений в коде проекта;
- PIE-чек-лист: WASD, мышь (инверсия по настройке), Space, Ctrl, Shift; камера не проходит сквозь стены;
  руки видны только игроку.

### Этап 2 — Оружие: стрельба, перезарядка, боезапас ⬜
Файлы: `Weapons/IntAmmoState.h` (+ .cpp), `Weapons/IntWeaponData.*`, `Weapons/IntWeapon.*`,
изменения в `IntPlayerCharacter.*` (Fire/Reload input), `Config/DefaultEngine.ini` (канал `Weapon`),
`Private/Tests/IntAmmoStateTests.cpp`.
Проверка:
- автотесты `INTGames.Weapons.Ammo`: выстрел уменьшает магазин; пустой магазин не стреляет;
  перезарядка берёт из запаса не больше нужного; перезарядка при полном магазине/пустом запасе невозможна;
- PIE: темп стрельбы соответствует `DA_`, попадание по кубу с физикой даёт импульс и декаль,
  `OnAmmoChanged` выводится в лог/временный HUD.

### Этап 3 — Здоровье, урон, смерть ⬜
Файлы: `Components/IntHealthComponent.*`, подключение к игроку, `Private/Tests/IntHealthComponentTests.cpp`.
Проверка:
- автотесты `INTGames.Health`: урон уменьшает здоровье, не уходит ниже 0, `OnDeath` вызывается ровно один раз,
  урон после смерти игнорируется, лечение ограничено `MaxHealth`;
- PIE: `BP_DamageVolume` наносит урон игроку, при 0 — смерть и рестарт уровня.

### Этап 4 — Базовый противник с ИИ ⬜
Файлы: `AI/IntEnemyCharacter.*`, `AI/IntEnemyAIController.*`, `AI/BTTask_IntFireWeapon.*`,
`AI/BTTask_IntReload.*`, `AI/BTService_IntUpdateTarget.*`; `INTGames.Build.cs` (+ `AIModule`, `NavigationSystem`, `GameplayTasks`).
Редактор: `BP_Enemy_Grunt`, `BB_Enemy`, `BT_Enemy`, NavMesh на тестовой карте.
Проверка:
- PIE: враг патрулирует; замечает игрока в конусе зрения, не видит за стеной; сближается и стреляет
  (с разбросом), перезаряжается; при уроне со спины разворачивается; теряет игрока → ищет → возвращается;
  при смерти — ragdoll, отключение коллизии/ИИ, исчезновение через N секунд;
- функциональный тест на карте `L_Test_AI` (FunctionalTest актор): враг погибает от N выстрелов = ceil(HP/Damage).

### Этап 5 — Система целей и переход между стадиями ⬜
Файлы: `Mission/IntMissionData.*`, `Mission/IntMissionObjective.*` (+ 3 подкласса),
`Mission/IntMissionSubsystem.*`, `Mission/IntObjectiveTrigger.*`, `Mission/IntInteractable.*`,
`Config/DefaultGameplayTags.ini`, `Private/Tests/IntMissionTests.cpp`.
Проверка:
- автотесты `INTGames.Mission`: стадия завершается только когда все цели выполнены; переход на следующую;
  после последней — `OnMissionCompleted` ровно один раз; повторные сигналы не ломают счётчики;
- PIE: тестовая миссия из 3 стадий (дойти → убить 2 врагов с тегом → нажать терминал) проходится, лог стадий корректен.

### Этап 6 — HUD и экран завершения миссии ⬜
Файлы: `UI/IntHUDWidget.*`, `UI/IntMissionEndWidget.*`, изменения `IntPlayerController.*`, `IntGameMode.*`.
Редактор: `WBP_HUD`, `WBP_MissionComplete`, `WBP_Death`.
Проверка (PIE): здоровье/патроны/текст цели обновляются по событиям; по завершении миссии — ввод
переключается в UI, курсор, кнопки «Заново»/«Выход» работают; экран смерти → рестарт.

### Этап 7 — Миссия 10–15 минут ⬜
Блокаут уровня `L_Mission_01`, `DA_Mission_01` (4–5 стадий), расстановка 15–25 врагов, баланс.
Проверка: 3 полных плейтеста с замером времени; упаковка `BuildCookRun` и запуск собранного `.exe`.

## 4. Риски и ограничения
- Без редактора агент не может создавать ассеты и запускать PIE — каждая визуальная проверка требует человека.
- Сборка в CI возможна только на self-hosted Windows-раннере с установленным UE (можно добавить на этапе 2–3).
- Графика/анимации/звук в первой версии — из шаблона First Person и бесплатных паков Epic (Fab).
