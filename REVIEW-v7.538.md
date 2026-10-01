# v7.538 keyboard transition evidence

Baseline: 92fe5be4 (v7.537). This is a diagnostic release, not a confirmed keyboard repair.

The four-second supplied video shows a dark uppercase keyboard with prediction suggestions during the sheet presentation (around 1.0–1.5 seconds). By approximately 2.0 seconds it has white lowercase keys, the suggestions have disappeared, and the special-key/dock glyphs are dark. The keyboard floor remains black. These simultaneous changes suggest an input configuration transition; they do not establish its source.

The v7.535 transition file contains 1,089 NATIVE_FRAME events and ends about 22.21 seconds after SESSION_START. UIInputSetHostView and _UIRemoteKeyboardPlaceholderView have recorded black backgrounds during keyboard appearance/recreation. It contains no keyboard appearance setter/getter values, focused-input configuration records, or remote keycap pixels. Therefore it did not capture enough evidence to prove why the skin switched. The v7.537 extended-traits hook may or may not be reached on this iOS version; the old trace cannot answer that.

Changes:
- Armed transition captures log legacy UITextInputTraits appearance writes without changing their arguments.
- Existing extended-trait setter/reset and WebKit trait-read paths log class/object identity and numeric keyboard appearance, type, autocapitalization, autocorrection, spellcheck and return-key settings.
- Keyboard show/hide/frame notifications include end frame and whether legacy/extended trait classes exist.
- The existing finite web transition sampler tracks active-element identity and configuration changes. Focus events also trigger records. No input value, entered text or keyboard pixels are collected.
- Native records stop at 512 per session with an explicit limit flag; DOM input records stop at 256. DOM event listeners are removed at capture shutdown. No new production scan, timer, observer, or appearance mutation was added.
- Existing OLED floors, modal paint, geometry and keyboard policy are retained. All exports remain separate plain TAR sessions.

Reproduction: install the CI-built package, arm TRANSITION, open Amazon and repeat precisely the sequence in the video. Leave the bad keyboard visible for two seconds, then return to NewTerm and export. Include a short recording if the visual state still changes: remote keycap pixels are outside the app-local probe's visibility.

The frozen transition-payload hashes were deliberately updated because its diagnostic content changed. C99/C++98 embedding checks remain enabled, alongside a new runtime fixture testing deduplication, same-focus configuration changes, focus replacement, expiry and record caps.
