# Little16 With Settings

Little16 with a **Settings pane** (Settings > Little16 With Settings) to toggle each feature.

Enable iPhone X Gestures on iOS 15 - 26?

## Settings
* **Enable Little16** – master switch (off = stock iOS behaviour)
* **Gestures** – iPhone X home gesture, Control Center from the top edge, hide the home bar
* **Dock** – floating dock, dock style (floating rounded or classic edge-to-edge square), recent apps in the dock (+ how many: 1-5), App Library in the dock, number of dock icons (4-6)
* **Status Bar** – iPad status bar
* **Lock Screen** – flashlight / camera quick actions, notification position fix
* Respring and Reset buttons

Most toggles apply live; dock / status bar / gesture changes may need a respring.

## Build
Requires [Theos](https://theos.dev) with an iOS 15+ SDK.

    make package

The package replaces `com.michaelmelita1.little16` (Conflicts/Replaces) and depends on `preferenceloader`.

## Compatibility

Tested on iPhone 6S, 7 & 8. May be compatible with SE 2 on iOS 26. Give it a shot and let me know

## Credits
* michaelmelita1 | original [Little16](https://github.com/michaelmelita1/Little16)
* ETHN | [FloatingDockXVI](https://github.com/nahtedetihw/FloatingDockXVI)
* Ryan Nair | [Little12](https://github.com/ryannair05/Little12)
* duraidabdul | [Neptune](https://github.com/duraidabdul/Neptune)

## Things to Fix
* iOS 17+ specific fixes (Status Bar, Quick Actions being in wrong place)
