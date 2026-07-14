# AMaps — нативный iOS-таргет

SwiftUI-приложение поверх готового Swift-пакета `AMaps` (домен, fog-движок,
трекинг, хранилище). Карта — **MapLibre Native** с теми же CARTO Voyager
тайлами, что и веб-прототип.

## Сборка

Проект генерируется из `project.yml` через [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(сам `.xcodeproj` не коммитится):

```bash
brew install xcodegen        # один раз
cd ios
xcodegen generate            # создаёт AMaps.xcodeproj
open AMaps.xcodeproj          # дальше как обычно в Xcode
```

Или из командной строки в симулятор:

```bash
xcodebuild -project AMaps.xcodeproj -scheme AMaps \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Статус

Milestone 1 (готово): приложение собирается и запускается — карта MapLibre по
центру Дананга, плашки региона/ячеек, primary-кнопка «Поехали» (стартует
сессию через `AppComposition`).

Дальше: слой тумана войны (инвертированный полигон облаков с дырами по открытым
ячейкам), живая сессия с раскрытием коридора, CoreLocation/CoreMotion, шторки
(журнал/ачивки/профиль), H3-сетка, StoreKit.
