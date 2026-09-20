# DuoCut — план реализации

> Файл — источник правды о прогрессе. Отмечай `[x]` сразу после того, как пункт сделан и проверен,
> и начинай новую сессию с первого незакрытого пункта. Команды проверки — в конце файла.

## Context

Новый вирусный проект в линейке Accorduon / Duogami / SandValley / ClawKit / DuoBird: **DuoCut** — игра для iPhone Duo, где разрез фигуры делается физическим сгибом телефона.

Ключевая идея жанра: линия реза неподвижна — она всегда на шарнире. Поэтому игрок не водит нож по фигуре, а **двигает и вращает фигуру под неподвижный нож**, затем складывает телефон. Линия берётся из `reservedRegions(kind: .division, options: [.includeInactive])`, а не рисуется «по центру» — это и есть честная демонстрация API.

Два режима: **Puzzle** (точность, заданные уровни, тематические паки) и **Arcade** (летящие фрукты, тайминг хлопка). Плюс ачивки, счётчик сгибов, шара-карточка.

Отдельный репозиторий `~/Developer/DuoCut`, публичный на GitHub в конце. Конвенции копируем с DuoBird (`~/Developer/DuoBird`): JSON-формат проекта `project.xcproj`, Swift 6, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, deployment target 27.1, SwiftUI-only, `Canvas` + `TimelineView` + собственная мини-физика, никакого SpriteKit.

Работа разбита на фазы, каждая — отдельная сессия/сабагент. Прогресс трекается чекбоксами в `docs/ROADMAP.md` внутри репо.

## Решения по геймплею

- **Вращение** — rotation gesture двумя пальцами (drag одним пальцем = перенос).
- **Рез** — резкий хлопок сгибом (10–15°, как flap в DuoBird), а не медленное складывание до порога. Быстро, повторяемо, годится и для аркады.
- **Визуал** — минимализм: пастельная палитра, плоские фигуры, крупная типографика, много воздуха (референс — Cutle).
- **Дейли-челлендж** — в scope, Фаза 6: одна фигура в день (seed от даты), один рез, процент + стрик, шара-карточка.

---

## Целевая структура

```
~/Developer/DuoCut/
  AGENTS.md                      # конвенции проекта (по образцу DuoByExamples/AGENTS.md)
  docs/ROADMAP.md                # чекбоксы фаз — источник правды о прогрессе
  README.md, LICENSE, .gitignore
  DuoCut.xcodeproj/project.xcproj
  DuoCut/
    App/DuoCutApp.swift          # @main, statusBarHidden, persistentSystemOverlays(.hidden)
    App/RootView.swift           # меню: Puzzle / Arcade / Achievements
    Geometry/Polygon.swift       # вершины, площадь (shoelace), центроид, bbox, трансформ
    Geometry/PolygonCut.swift    # split полигона прямой → ([Polygon], [Polygon])
    Geometry/Line.swift          # точка + направление, signed distance
    Fold/FoldLine.swift          # division region (+fallback) → линия реза в координатах вью
    Fold/CutDetector.swift       # поток углов шарнира → прогресс реза, коммит, скорость хлопка
    Play/Piece.swift             # кусок после реза: позиция, скорость, вращение, шаг физики
    Play/BladeOverlay.swift      # отрисовка лезвия/линии + свечение по глубине сгиба
    Puzzle/PuzzleGame.swift      # @Observable: уровень, цель, счёт, звёзды, прогресс
    Puzzle/PuzzleView.swift
    Puzzle/Level.swift + Levels.swift  # паки уровней, заданные руками
    Arcade/ArcadeGame.swift      # спавн, полёт, комбо, бомбы, жизни
    Arcade/ArcadeView.swift
    Meta/Achievements.swift      # каталог + хранилище в UserDefaults
    Meta/AchievementsView.swift, Meta/ShareCard.swift, Meta/FoldCounter.swift
    Resources/Assets.xcassets
  DuoCutTests/                   # Swift Testing, только чистая геометрия
    PolygonTests.swift, PolygonCutTests.swift
```

---

## Фазы

### Фаза 1 — Скелет проекта
- [x] `~/Developer/DuoCut`, `git init`, `.gitignore` и `LICENSE` скопировать из DuoBird.
- [x] `DuoCut.xcodeproj/project.xcproj` — на основе `~/Developer/DuoBird/DuoCut.xcodeproj/project.xcproj`: переименовать таргет/продукт, bundle id `com.artemnovichkov.DuoCut`, добавить группы `App/Geometry/Fold/Play/Puzzle/Arcade/Meta/Resources` и тест-таргет `DuoCutTests` (Swift Testing, `build-phases: compile-sources`, `TEST_HOST`).
- [x] `Assets.xcassets`: AccentColor + пустой AppIcon (иконка — в Фазе 7).
- [x] `DuoCutApp.swift` + заглушка `RootView`.
- [x] `AGENTS.md` и `docs/ROADMAP.md` (эти же фазы чекбоксами + команды сборки/запуска/hinge).
- Готово, когда: `xcodebuild -project DuoCut.xcodeproj -scheme DuoCut -destination 'platform=iOS Simulator,name=iPhone Duo' build` зелёный, приложение стартует, `xcodebuild test` проходит на пустом тест-таргете.

### Фаза 2 — Геометрия (чистая, под тестами)
- [x] `Polygon`: `[CGPoint]`, `area` (shoelace, знак нормализуем), `centroid`, `boundingBox`, `path`, `applying(translation:rotation:)`, `contains(_:)`.
- [x] `PolygonCut.split(_:by:)`: signed distance по вершинам, вставка точек пересечения, обход контура с разделением на цепочки → массивы полигонов по каждую сторону. Обязательно корректно для **вогнутых** фигур (несколько пересечений) и для случаев «линия не задевает / касается вершины».
- [x] Тесты: квадрат пополам (50/50), по диагонали, круг-аппроксимация, L-образная (вогнутая, 2 пересечения), C-образная (4 пересечения → 3 куска), линия мимо фигуры, линия через вершину, вырожденные и почти-параллельные случаи, сумма площадей == площади оригинала (с допуском).
- Готово, когда: тесты зелёные, никакого UI-кода в `Geometry/`.

### Фаза 3 — Нож на шарнире (ядро ощущения)
- [x] `FoldLine.from(proxy:)`: `proxy.reservedRegions(kind: .division, options: [.includeInactive]).first`; ось — по соотношению сторон рамки (вертикальный / горизонтальный фолд, как в `AvoidDivisionExample.swift`); fallback без шарнира — вертикальная линия по центру контейнера. Читать **внутри** `GeometryReader`, не кэшировать.
- [x] `CutDetector` (по образцу `DuoBird/Game/FlapDetector.swift`): ловит **резкий хлопок** — сгиб на 10–15° от локального максимума. Отдаёт момент коммита и скорость (°/с) для оценки «чистоты» реза; rearm — новый рез только после разгибания назад на ~5°. Плавный `progress` по текущему углу — только для подсветки лезвия перед хлопком.
- [x] `BladeOverlay`: линия/лезвие ровно на фолде, входит в фигуру по `progress`, свечение + `sensoryFeedback(.impact)` на коммите.
- [x] `Piece`: после реза — разлёт половинок (гравитация, импульс от ножа в стороны, вращение), шаг в `TimelineView(.animation)`.
- [x] Fallback-ввод: свайп поперёк линии реза режет так же — проверено на iPhone 18 Pro (iOS 27.2): свайп через линию разваливает фигуру.
- Готово, когда: на симуляторе iPhone Duo фигура реально разваливается при сгибе (проверять скиллом `hinge` + `simctl io booted screenshot`), и свайпом на обычном iPhone.

### Фаза 4 — Puzzle-режим
- [x] `Level`: полигон(ы), стартовый трансформ, токены (звёзды/цветные точки), `cutsAllowed`, цель:
  `.equalHalves`, `.ratio(Double)`, `.separateColors`, `.tokensPerSide(Int)`.
- [x] Ввод: drag одним пальцем — перенос, rotation gesture двумя — поворот (`simultaneousGesture`); лёгкий снап к «красивым» углам, но без магнита к правильному ответу.
- [x] Live-HUD: проценты площадей пересчитываются **до** реза, по текущему положению фигуры относительно линии.
- [x] Оценка: ⭐⭐⭐ по |Δ| (3★ < 1%, 2★ < 3%, 1★ < 6%), результат-карточка, «следующий уровень».
- [x] Мульти-рез: последующие резы применяются к уже полученным кускам.
- [x] Book pose: заголовок и HUD сдвигаются так, чтобы не попадать в division; игровое поле остаётся на весь экран (иначе фигуре не дотянуться до ножа).
- [x] Прогресс (звёзды по уровням) в `UserDefaults`, `Codable`.
- [x] Пак №1 «Basics»: 8–10 уровней от квадрата к вогнутым фигурам.
- Готово, когда: пак проходится целиком, звёзды сохраняются между запусками.

### Фаза 5 — Arcade-режим
- [x] Фрукты/фигуры летят по параболам через экран; хлопок сгибом режет всё, что в этот момент пересекает линию фолда.
- [x] Комбо за несколько объектов в один хлопок, бомбы = конец игры, пропуск = жизнь (3 жизни).
- [x] Нарастающая сложность, счёт + рекорд в `UserDefaults`, разлёт половинок на общей физике из Фазы 3.
- Готово, когда: режим играется от начала до game over, рекорд сохраняется.

### Фаза 6 — Мета: паки, ачивки, шара
- [x] Паки №2–4: «Fruit» (вогнутые + токены), «Constellations» (`tokensPerSide`), «Mosaic» (мульти-рез, `ratio`). Прогрессия сложности внутри пака, пак открывается по звёздам.
- [x] `Achievements`: каталог + `UserDefaults`, тост при разблокировке, экран списка. Например: первый идеальный рез (ровно 50.0%), 10 идеальных, комбо ×5 в аркаде, пак на все звёзды, «Hinge Warranty Voided» на 1000 сгибов.
- [x] `FoldCounter`: глобальный счётчик сгибов, показывается на экране результатов (самоирония про убитые шарниры).
- [x] Дейли-челлендж: фигура дня из seed по дате (одна и та же у всех), один рез, результат в процентах, стрик и история последних дней в `UserDefaults`, повтор за день запрещён.
- [x] `ShareCard` через `ImageRenderer` + `ShareLink`: фигура, разрез, процент, название уровня / номер дня и стрик.
- Готово, когда: ачивки разблокируются и переживают перезапуск, дейли даёт одну и ту же фигуру в течение дня, шара-карточка рендерится.

### Фаза 7 — Полировка и публикация
- [x] Иконка, AccentColor, звук/гаптика, анимации переходов, пустые состояния.
- [x] Скриншоты/гифки: `.github/images/` (`-folded`, `-book` суффиксы для состояний сгиба).
- [x] `README.md` в стиле DuoBird: что это, требования, геймплей, какие API использованы, «Good to Know» про division region и её активность только при частичном сгибе.
- [x] `gh repo create artemnovichkov/DuoCut --public`, пуш.
- [x] В `DuoByExamples/README.md` → «See Also» добавить строку про DuoCut.
- Готово, когда: репо публичный, README с картинками, ссылка из каталога есть.

---

## Проверка

- Сборка: `xcodebuild -project DuoCut.xcodeproj -scheme DuoCut -destination 'platform=iOS Simulator,name=iPhone Duo' build`
- Тесты геометрии: `xcodebuild test -project DuoCut.xcodeproj -scheme DuoCut -destination 'platform=iOS Simulator,name=iPhone Duo'`
- Запуск: `xcrun simctl launch booted com.artemnovichkov.DuoCut`
- Сгиб: скилл `hinge` (fold / half-open / unfold, чтение угла); скриншот внутреннего дисплея `xcrun simctl io booted screenshot`, внешнего — `--display=1`.
- Ручной прогон каждой фазы на симуляторе + проверка fallback-свайпа на обычном iPhone.

---

## Решено на старте

Вращение двумя пальцами · рез хлопком · минималистичный визуал · дейли-челлендж в scope (Фаза 6).
