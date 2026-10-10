# autoKSHelp

A macOS menubar app that pops up the keyboard shortcuts of the frontmost app, read from its menu bar. Built with Swift/SwiftUI. Version 0.0.2.

## Usage

| Action | How |
| --- | --- |
| Show / cycle | **⌃⌘/** — shortcuts → shortcuts + other commands → hidden (or menubar icon → *Show Shortcuts*) |
| Open with other commands, then toggle them | **⇧⌃⌘/** |
| Show alternate menu items | Hold **⌥ Option** |
| Search | Just type (title, menu path or keys) |
| Run a command | Click a row, press **Enter** (first match), or type its shortcut (needs ⌘ or ⌃, or an F-key) |
| Hide | **Esc** or click elsewhere |
| Move | Drag any empty part of the popup |

The popup has four columns, a fixed height (70% of the screen), light/dark/system appearance buttons, and a header toggle for *Other Commands* — enabled menu items without a shortcut, listed below the shortcuts.

## Changelog

- **0.0.2** — hotkey changed from ⌃⌥⌘/ to **⌃⌘/** (and ⇧⌃⌘/): holding Option as part of the hotkey made the Option alternates show as soon as the popup opened.
- **0.0.1** — first release.

## Requirements

macOS 13+, Swift 5.9+ toolchain. Grant Accessibility permission (System Settings › Privacy & Security › Accessibility).

## Build

```sh
./build.sh      # release build -> autoKSHelp.app (codesigned)
./install.sh    # build, sign, install to /Applications, launch
swift test      # unit tests
```

Signing uses a local certificate ("CmdTab Local Signing" / "autoKSHelp Local Signing", created if missing) so the Accessibility grant survives rebuilds; override with `CODESIGN_IDENTITY`.

## Layout

- `Sources/KSCore` — shortcut model, key/modifier formatting, matching (unit tested)
- `Sources/autoKSHelp` — app, Accessibility menu reader, popup panel, SwiftUI view, hotkeys
- `SPEC.md` — original spec plus implemented behavior
