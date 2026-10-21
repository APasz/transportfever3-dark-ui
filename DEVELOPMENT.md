# Dark UI runtime limitations and fixes

Transport Fever 3's embedded Lua and native UI APIs differ from the host Lua
interpreter used for tests. Keep confirmed runtime failures, test reproductions,
and unresolved reports distinct. A passing host test does not establish native
rendering behaviour.

When adding an issue, record its symptom, evidence, cause where known, fix or
workaround, and regression coverage. Add the game build and platform when known;
do not infer a Lua version or engine limit from a single failure.

## Embedded Lua lacks table.move

**Confirmed in game on 2026-10-20; code fix and regression coverage added.**

Startup failed with `attempt to call field 'move' (a nil value)` while rendering
`UiTweaksSettingsButton`. Dark UI had introduced `table.move` to prepend a button
reference. The host interpreter provided it, so local validation missed the crash.

Use a backward loop over the packed argument count when shifting arguments.
Preserve `nil` gaps and trailing arguments; `#arguments` and `table.insert` do not
reliably express the length of a sparse argument list.

[The theme script](content/gui/main/dark_ui_game_bar_theme.script.lua) uses that
loop. [The React bridge tests](tests/inline_styles_test.lua) load the theme with
`table.move` removed from its environment and check argument preservation.

## React parameters are not necessarily the last argument

**Reproduced with shipped React in tests; fixed.**

Our interceptors could skip styling or lose an icon's supplied stylesheet when a
valid call ended with `nil` or another extra argument. React accepts optional
`react.style(...)` and `react.ref(...)` prefixes, in either order. The parameters
follow those prefixes; extra arguments can follow the parameters.

Use the theme script's shared `getRecipeParams` helper. Forward the original
argument count with `table.pack(...).n` and explicit unpack bounds. Preserve
existing reference lists and metadata when adding Dark UI overrides.

The React bridge tests cover both prefix orders, trailing `nil` arguments, gaps,
extra arguments, and icon metadata.

## React content belongs to its calling recipe

**Constraints covered by the React bridge tests.**

Content nodes cannot be passed between unrelated recipe contexts. A registered
wrapper must return its direct wrapped child; wrapping that return value in an
additional metadata node violates the wrapper contract.

Construct icon and button content in the owning context. Use UI Tweaks'
`interceptActive` helper for inline changes that must preserve that context, and
`wrapActive` for the GameBar root wrapper. Compose existing replacements rather
than bypassing them.

The bridge tests reject foreign content nodes and invalid wrapper returns, and
check that active replacements still run.

## Image tracking must preserve hook order

**Regression covered using the shipped Load Game TileElement recipe.**

Save cards change their image count between renders. Adding a state or reference
hook for every intercepted `ImageView` would shift the owning recipe's later hook
slots, including its own node references.

Keep image tracking free of hooks. The current implementation tracks nodes by
calling context, clears them with one queued join per render, and only tracks
eligible toolbar recipes. Unrelated menus should incur no image tracking or
cleanup jobs. The bridge tests check hook counts, cleanup batching, and release
of previous image handles.

## Native styles need explicit reset and careful merging

**Native retention is modelled in tests; renderer precedence needs game checks.**

Omitting `styleSheet` metadata can leave a previous native override in place. To
return to Vanilla, submit an empty native stylesheet when the caller supplied no
stylesheet. If another mod supplied a stylesheet, preserve it instead. Partial
resets must remove only Dark UI's overrides.

Native `StyleSheet` userdata cannot be copied with `pairs`. Use the documented
field list in [the GUI utility](content/gui/main/dark_ui_gui_util.lua). Re-read
the supplied sheet when merging because other mods can mutate it without changing
its identity. Border images must be native `NinePatch` objects. The None choice
uses an empty border image and the palette's invisible colour; Vanilla applies no
border override.

The bridge tests cover native field validation, stylesheet mutation, partial and
full reset, and shared style and border image caches.

## Optional UI Tweaks integration has loading constraints

**Compatibility behaviour covered by automated tests.**

The base palette works without UI Tweaks. A settings resource alone does not prove
that the installed UI Tweaks version has the helper modules Dark UI needs.

A failed game `require` can leave its module path stack unbalanced. Preflight
optional helper files with `resolveutil.loadfile` before requiring them. The
[integration module](content/gui/main/dark_ui_ui_tweaks.lua) checks helper
functions and logs one warning when missing files or older helpers disable game
bar customisation. Syntax errors, invalid module values, and incompatible settings
APIs still raise errors.

Upload validation also loads scripts before the runtime resource API is available.
Keep resource lookups and runtime-only dependencies inside `install`.

Coverage: [compatibility tests](tests/ui_tweaks_compatibility_test.lua) and
[settings UI tests](tests/settings_ui_test.lua).

## Current styling boundaries

- Direct `Button`, `ToggleButton`, and `ToolButton` calls in registered mod toolbar
  recipes receive optional icon tinting regardless of CSS class. Their backgrounds
  and borders retain standard or mod-specific styling. Standard toggle backgrounds
  therefore follow Layers rather than the Game bar background setting. Direct
  `ImageView` content can be tinted; nested or unknown content is left untouched
  to avoid recolouring text.
- Toolbar targeting uses known recipe identities and registered replacement chains.
  There is no public ancestry lookup used by this integration, so a global `extra`
  selector would also affect unrelated windows. The built-in GameBar context help
  button still requires the `extra` class within its known recipe.
- The game-bar stylesheet generates 12 rules; the build-control stylesheet adds
  one rule. The game-bar count is a tested project budget, not an established
  engine ceiling. Do not describe the reported stylesheet limitation as a
  confirmed numerical engine limit.
- Signal icons are reported as unaffected by interface themes in
  [the mod description](_metadata/description.html). Their cause and a fix remain
  unresolved. Colours baked into textures and custom skins can also remain
  unaffected by shared palette changes.

## Toolbar classes differ between mods

**Different backgrounds reported in game on 2026-10-20; targeting fix covered by tests.**

With the background setting at Black, UI Tweaks, Noter, and SignalWay had black
buttons while other toolbar buttons remained grey. Dark UI only styled mod
`ToggleButton` calls carrying the `extra` class. Those three mods use it, but
Timetables uses `celmi-tt-toolbar-btn`; other registered toolbar entries also use
plain action buttons or omit a class entirely.

Identify mod toolbar buttons by their registered recipe, independently of their
CSS classes. Support action, toggle, and tool buttons through the shared styling
path, and only attach toggle callbacks to toggle buttons. Preserve supplied classes,
callbacks, and borders. The bridge tests cover custom and absent classes, button
states, action callbacks, tool selection, and resets, while rejecting buttons in
unrelated windows. Background overrides were subsequently excluded from mod
buttons as described below; recipe targeting still applies to icon tinting.

## Mod toolbar backgrounds follow Layers

**Required styling baseline clarified on 2026-10-20; override exclusion covered by tests.**

Mod toolbar buttons should retain the standard shared-palette background used by
the Layers button, independently of the Game bar background setting. Applying that
setting to mod buttons made UI Tweaks, Noter, and SignalWay black when Layers was
grey.

The shipped `gui/layers/layers.css.lua` sets Layers button geometry without replacing
its background. `gui/main/builtin.css.lua` supplies the standard toggle state
colours, including `BaseMedium` when unchecked and `AccentMedium` when checked.
Use that native styling instead of duplicating its colours or state rules in Lua.

Dark UI submits no background or border overrides for mod toolbar buttons. An empty
stylesheet clears a previous Dark UI override when the caller supplied no sheet;
an existing mod sheet is preserved. Icon tinting remains optional. Built-in game
bar buttons retain their own background controls. Custom skins or hard-coded mod
backgrounds can still differ from Layers.

The bridge tests check that every game bar background and border choice leaves mod
button styles intact across states, classes, and button types. Native appearance
after this change still needs an in-game check.

## Validation and its limits

Run basic checks from the repository root:

```sh
bash tools/validate.sh
```

Include the installed game's sources for React, stylesheet parser, and palette
checks:

```sh
bash tools/validate.sh "/path/to/Transport Fever 3"
```

The tests also expect the sibling `../ui_tweaks` checkout and the shared logging
symlink. [The validation script](tools/validate.sh) defines the checks;
[the source loader](tests/game_source.lua) reads the installed game archives.
Compiling Teal to a Lua target does not establish the functions available in the
embedded runtime.

Native API stand-ins check argument flow and model known behaviour. They do not
render the UI or establish stylesheet precedence, native interaction, or an engine
rule limit. After runtime or styling changes, check startup, Load Game, button
states, Vanilla/reset behaviour, and representative mod toolbar buttons in game.

For a new failure, keep the exact error and relevant `stdout.txt` stack trace with
the reproduction steps. Record whether the failing path is the working tree or a
staged copy, and whether that copy is linked to the source or was copied earlier.
## Settings translations

**Found by source inspection during the metadata audit; host checks cover the fix.**

Game-bar option labels and descriptions were plain English strings. Routing those
strings through the game's translation function and adding a root `strings.json`
lets all 13 game languages use the same settings definitions. Stored setting keys,
choice IDs, defaults, and style values are unchanged.

The shared description checks validate every catalogue and placeholder. Localised
resource fixtures exercise the settings in each language; the existing settings
and React tests use the shared English translation fixture. These checks do not
establish native text layout. Restart the game and inspect long settings labels
in the desired language when verifying the interface in game.
