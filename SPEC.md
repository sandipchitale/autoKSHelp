# autoKSHelp

Develop a menubar applet that generates a keyboard shortcuts popup using the frontmost apps menu. With options alternate actions. So if I hold the Option key down show those actions instead. The display should be a nicely formated light weight popup window that appeares at the screen center. Add search at the top to narrow down the list. Escape should hide the popup. Use Swift/Swift UI.

## Implemented behavior (v0.0.3)

**Popup**
- Menubar applet (no Dock icon); the menu shows the app name and version, *Show Shortcuts*, *Show Other Commands* (toggle), *Accessibility Settings…* and *Quit*.
- Borderless popup centered on screen, 70% of the usable screen height and at most 1600 px wide, draggable by any non-interactive spot. It does not steal focus from the frontmost app, and hides on Escape or when it loses focus.
- Fixed 4-column layout with the shortcut right next to the action name, grouped by top-level menu. The height never changes while the popup is open; the vertical scrollbar space is always reserved so the layout does not shift.
- Search field at the top (focused on open) filters by title, menu path or keys. Appearance buttons: Light (default, white), Dark, System.

**Content**
- Shortcuts are read from the frontmost app's menu bar through the Accessibility API (permission required).
- Holding **Option** shows the alternate menu items (e.g. Close All) in place of their base items; an "⌥ Alternates" label (space always reserved) indicates it.
- *Other Commands*: enabled menu commands without a shortcut are listed in a separate section below the shortcuts (off by default; header toggle or menubar item).

**Running commands**
- Click a row, press Enter (first match), or type the shortcut itself (needs ⌘ or ⌃, or an F-key) to run the command in the frontmost app via its menu item.

**Hotkeys**
- **⌃⌘/** cycles: shortcuts → shortcuts + other commands → hidden.
- **⇧⌃⌘/** opens with other commands shown.
- Once the popup is open, each press of **Shift** alone shows/hides the other commands.

**Note:** the hotkeys deliberately avoid Option, since holding Option selects the alternate menu items and would show them the moment the popup opens.

**Design principle:** the UI must stay stable. Conditional elements reserve their space; layout moves only when the interaction implies it (e.g. expanding an accordion).

**Build**: `./build.sh` (bundle + codesign), `./install.sh` (build, sign, install to /Applications, launch), `swift test`.
