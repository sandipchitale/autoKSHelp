# autoKSHelp

Develop a menubar applet that generates a keyboard shortcuts popup using the frontmost apps menu. With options alternate actions. So if I hold the Option key down show those actions instead. The display should be a nicely formated light weight popup window that appeares at the screen center. Add search at the top to narrow down the list. Escape should hide the popup. Use Swift/Swift UI.

## Implemented behavior (v0.0.13)

See `screenshots/autoKSHelp.png` (light) and `screenshots/autoKSHelp-alternates.png` (dark, Alternates on) for the popup: 4 columns, header toggles, export and appearance buttons.

**Popup**
- Menubar applet (no Dock icon, no windows at launch — plain AppKit entry point, no SwiftUI app scene); the menu shows the app name and version, *Show Shortcuts*, *Show Other Commands* (toggle), *Accessibility Settings…* and *Quit*.
- Borderless popup centered on screen, 70% of the usable screen height and at most 1600 px wide, draggable by any non-interactive spot. It does not steal focus from the frontmost app, and hides on Escape or when it loses focus.
- Fixed 4-column layout with the shortcut right next to the action name, grouped by top-level menu. The height never changes while the popup is open; the vertical scrollbar space is always reserved so the layout does not shift.
- Search field at the top (focused on open) filters by title, menu path or keys. Appearance buttons: Light (default, white), Dark, System.

**Content**
- Shortcuts are read from the frontmost app's menu bar through the Accessibility API (permission required). Arrow and function keys, which menus report as private-use Unicode characters (U+F700…), are translated to symbols (↑ ↓ ← →, F1–F35, ⌦, ⇞ …) so no key renders as a missing-glyph box, and so typed shortcuts match menu shortcuts.
- Tapping **Option** on its own toggles the alternate menu items (e.g. Close All) in place of their base items, so it need not be held. The header has a toggle button **⌥ Alternates** (clickable too) that shows the state; its label is constant so the layout never shifts. (The original spec said to hold Option; it was changed to a toggle on request.)
- *Other Commands*: enabled menu commands without a shortcut are listed in a separate section below the shortcuts (off by default; toggled by tapping Shift on its own, the **⇧ Other Commands** header button, or the menubar item).

**Keyboard navigation**
- A row is always highlighted (the first one by default; hovering also selects). **↑/↓** move within a column, **←/→** move between columns (only while the search box is empty, otherwise they move the text cursor), **Tab/⇧Tab** step forward/back through all rows, wrapping around. The list scrolls to keep the selected row visible.

**Modifier taps**
- Shift (Other Commands) and Option (Alternates) toggle only when tapped *exclusively*: pressed and released alone, with no other key or modifier in between. ⇧Tab, ⌥⌘W or Shift+Option together never toggle. The toggle fires on release.

**Export (PDF / HTML)**
- Two header buttons (PDF, HTML) save the popup's *current state* — search filter, Other Commands on/off, and the light/dark appearance — through a save dialog. The popup stays open meanwhile, and its key handling ignores the dialog's keystrokes.
- Output is **landscape** in the same 4-column layout, with the app's icon, name, item count and date in the header. Both variants are exported at once: each item's Option alternate is listed directly below it (indented, accent color, ⌥ key tinted likewise), independent of the Alternates toggle; the header notes "Alternates (⌥)" in the same accent color.
- PDF: paginated (A4 landscape in metric locales, US Letter otherwise), vector text; a row and its alternate never split across columns, headers are never orphaned, and groups continue with a "(cont.)" header. HTML: one self-contained file (icon embedded as data) with `@page { size: landscape }`.

**Running commands**
- Click a row, press Enter (the highlighted row), or type the shortcut itself (needs ⌘ or ⌃, or an F-key) to run the command in the frontmost app via its menu item.

**Hotkeys**
- **⌃⌘/** shows the popup (shortcuts only) or hides it.
- **⇧⌃⌘/** opens with other commands shown.
- Once the popup is open, each tap of **Shift** alone shows/hides the other commands.

**Note:** the hotkeys deliberately avoid Option, since Option toggles the alternate menu items and would switch them on the moment the popup opens.

**Design principle:** the UI must stay stable. Conditional elements reserve their space; layout moves only when the interaction implies it (e.g. expanding an accordion).

**Distribution**: GitHub releases carry `autoKSHelp-<version>.zip` (the signed, non-notarized app); installation steps are in the README.

**Build**: `./build.sh` (bundle + codesign), `./install.sh` (build, sign, install to /Applications, launch), `swift test`.
