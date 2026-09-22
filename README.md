# AmazonDark v7.446 — probe responsiveness

Direct parent: v7.445 probe-transition-hardening. This includes its scale-aware Search → Product skeleton fix and separate compressed exports. Production theming is otherwise unchanged.

FULL inspects the main document in batches of at most 128 elements with an 8 ms cooperative batch budget, then scans document scrolling and up to eight large overflow containers. It reads actual offsets and waits for three stable bottom observations. Child-frame captures also yield between batches. Deep subtree text hashing and the redundant full-document scrollable pass are removed.

Scrolling is never disabled. Evaluation timeouts, a 240-second FULL deadline, stalled owners, backgrounding, node/step/output limits, missing frame responses and unfinished frame batches yield partial coverage reports. VIEWPORT has a 45-second deadline. A terminal VIEWPORT arm waits up to 30 seconds for Amazon to return to the foreground. Explicit UI capture ends an active transition recording so two heavy diagnostics do not run together.

FULL and VIEWPORT exports are mode-specific ZIPs. Partial captures are exportable, completed captures do not expire after 15 minutes, and exporting the same capture again replaces its same ZIP rather than creating duplicates. TRANSITION includes only the newest current-version recording from the current arm, not historical sessions.

These are bounded best-effort diagnostics, not a guarantee of every lazy-loaded or inaccessible frame. Reports explicitly leave cross-frame completeness unverified. Child frames are inspected but their internal scrolling is not driven; dynamically created overflow owners after the initial inventory may require a targeted VIEWPORT. No iPhone responsiveness or visual success is claimed until device testing.

Outstanding UI: white medium standalone ad; duplicate outer square ad border; compact top-ad title and sponsored info glyph; untamed large brand raster; missing Customers also bought artwork. The last two retain the earlier v7.444 source fixes, awaiting device confirmation. Other previously reported UI issues remain unverified, not closed.

See COMMANDS.md for push and three separate capture workflows.
