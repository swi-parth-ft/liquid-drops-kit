# LiquidDropsKit

Liquid-glass toast notifications for SwiftUI.

## Requirements

- iOS 17.0+
- Xcode 16+

## Installation (Xcode)

1. In Xcode, open your app project.
2. Go to `File` -> `Add Package Dependencies...`
3. Paste this URL:
   `https://github.com/swi-parth-ft/liquid-drops-kit`
4. Choose a dependency rule (`main` branch for now).
5. Add product `LiquidDropsKit` to your app target.

## Setup

Attach the host once at the app root:

```swift
import SwiftUI
import LiquidDropsKit

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .liquidDropsHost()
        }
    }
}
```

## Show a toast

```swift
import LiquidDropsKit
import UIKit

LiquidDrops.show(
    LiquidDrop(
        title: "Copied",
        subtitle: "Ready to paste",
        icon: UIImage(systemName: "checkmark.circle.fill"),
        position: .top,
        duration: .recommended,
        animationStyle: .init(coming: .bouncy, going: .snappy),
        effectStyle: .regular,     // iOS 26+
        materialStyle: .regular    // iOS 17-25 fallback
    )
)
```

## Options

- `position`: `.top` or `.bottom`
- `duration`: `.recommended`, `.nolimit`, or `.seconds(...)`
- `animationStyle`: choose toast appear/disappear animation using:
  - `coming`: `.spring`, `.snappy`, `.bouncy`, `.smooth`, `.easeInOut`, `.linear`
  - `going`: `.spring`, `.snappy`, `.bouncy`, `.smooth`, `.easeInOut`, `.linear`
- `effectStyle` (iOS 26+): `.regular` or `.clear`
- `materialStyle` (iOS 17-25): `.ultraThin`, `.thin`, `.regular`, `.thick`, `.ultraThick`
- `action`: trailing button with callback (`LiquidDrop.Action`)
- `glassTint`: optional tint color for the glass background

## Notes

- Swipe up on the toast to dismiss immediately.
- Top toasts animate from the Dynamic Island region on supported iPhones.
- On iOS 26+, the package uses glass effects.
- On iOS 17-25, it automatically uses the configured `materialStyle`.
