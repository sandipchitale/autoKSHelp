# autoKSHelp

A macOS menubar app that pops up the keyboard shortcuts of the frontmost app, read from its menu bar. Built with Swift/SwiftUI. Version 0.0.6.

## Usage

| Action | How |
| --- | --- |
| Show / hide | **⌃⌘/** (or menubar icon → *Show Shortcuts*) |
| Open with other commands shown | **⇧⌃⌘/** |
| Show / hide other commands (popup open) | Press **⇧ Shift** (releasing does nothing) or click the **⇧ Other Commands** header button |
| Show / hide alternate menu items (popup open) | Press **⌥ Option** (a toggle, like Shift) or click the **⌥ Alternates** header button |
| Search | Just type (title, menu path or keys) |
| Run a command | Click a row, press **Enter** (first match), or type its shortcut (needs ⌘ or ⌃, or an F-key) |
| Hide | **Esc** or click elsewhere |
| Move | Drag any empty part of the popup |

The popup has four columns, a fixed height (70% of the screen), light/dark/system appearance buttons, and two header toggle buttons, **⌥ Alternates** and **⇧ Other Commands**, whose labels show the key that toggles them. *Other Commands* are enabled menu items without a shortcut, listed below the shortcuts.

## Changelog

- **0.0.6** — Alternates and Other Commands are now toggle buttons in the header, each labelled with its key (⌥ / ⇧); the old state-changing label is gone.
- **0.0.5** — Option is now a toggle (press to show/hide alternates, no need to hold it); the header label reads "Alternates" when on.
- **0.0.4** — ⌃⌘/ now only shows (shortcuts only) or hides the popup; the header always shows a "Hold ⌥ for alternates" hint.
- **0.0.3** — with the popup open, pressing **Shift** alone shows/hides the other commands; ⇧⌃⌘/ now only opens the popup with them shown.
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
