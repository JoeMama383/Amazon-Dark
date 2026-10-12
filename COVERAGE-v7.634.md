# AmazonDark v7.634 — capture coverage

Base: v7.633 web-cache-cpp98-lists-nine-probe-repair. Input: Archive(20261011-132308).zip, containing 22 TAR captures. No screenshots were embedded in this archive. Names below are inferred from captured semantic DOM owners; repeated captures and submenu states are listed separately.

| Capture | Menu/state | Implemented coverage |
|---|---|---|
| 20261010-235603-085-r1 | Orders detail | Transactions/payment artwork; active delivery labels; recommendations and sponsored info backing. |
| 20261010-235733-668-r2 | Alexa voice history | History/thread surfaces, headings, muted metadata, filter rows and actions. |
| 20261010-235813-639-r3 | Content & Devices preferences | Digital payments; country/region; Amazon Family; saved Wi-Fi/Thread passwords; frustration-free settings; sync; automatic book updates; Personal Documents and tables. |
| 20261010-235859-118-r5 | Devices overview and tooltips | Alexa, Fire TV, Smart Home and app cards; device detail popovers; serial numbers; device artwork. |
| 20261010-235940-708-r6 | Content library and bulk dialogs | Content list, search, unchecked controls; deliver/remove, delete, mark read/unread, Family Library, collections; DeviceDialogBox and DialogSheet surfaces. |
| 20261011-000147-979-r1 | Your Books discovery and author intro | Outer tabs and filters plus nested Books shadow controls, cover art, price/format/rating labels; author-follow introduction. |
| 20261011-000242-581-r2 | Your Books introduction footer | Same component coverage plus yellow See It Now action and full-height introduction artwork. |
| 20261011-000349-872-r8 | Content library filters | Filter sheet, selected neutral fills, show-results action, Books/freebies ownership cards; selected border accents retained. |
| 20261011-000433-998-r9 | Privacy Settings | Landing cards, title/content containers and neutral headings. |
| 20261011-000541-738-r10 | Alexa privacy overview | Overview cards, navigation labels and section copy. |
| 20261011-000645-916-r11 | Alexa voice history (second state) | Same history and filter ownership, including selected state protection. |
| 20261011-000723-780-r12 | Detected Sounds history | History surfaces and expanded device/date filters. |
| 20261011-000811-123-r13 | Smart Home device history | Date accordion rows, state records and device-summary copy. |
| 20261011-000925-156-r15 | Alexa Activity custom dates | Custom date inputs, filter labels and gray separators. |
| 20261011-001056-955-r17 | Skill permissions and ad preferences | Scope names/empty states, preference descriptions and section dividers; toggle thumbs/checked track colors retained. |
| 20261011-001251-004-r18 | Manage Your Alexa Data | Section titles, descriptions, dropdown/navigation and recording/data choices. |
| 20261011-001417-543-r3 | Recording retention modal | Detached wide modal, choice descriptions, action buttons and close glyph. |
| 20261011-001534-128-r20 | Help Improve Alexa / Manage Data | Data-control descriptions, headings and section dividers; no toggle geometry changes. |
| 20261011-001957-598-r5 | Alexa help FAQ | Article headings, lists, body copy, existing controls and glyphs. |
| 20261011-002028-563-r22 | Alexa help article and feedback | Body/list text, feedback controls, box floors and dividers. |
| 20261011-002126-261-r23 | Help region/language picker | Picker floors, language glyph, illustration taming, link panels, article and feedback surfaces. |
| 20261011-092118-736-r1 | Buy Again | Mini-aisle/product artwork, delivery labels, ellipsis/info glyphs and action surfaces; cart progress floor/unfilled track. Authored pill radius and filled blue segment retained. |

## Preservation and verification boundaries

All 22 capture inventories were parsed and reviewed. The new module changes paint only; it adds no geometry, visibility, opacity, cropping, scroll or interaction changes. Exact photo leaves use the existing preference-controlled TWB factor. Stars, semantic links, selected accents, toggle thumbs and progress geometry are intentionally preserved.
Your Books requires styles inside nested Shadow DOM. A shared stylesheet is attached when the listed Books components create their roots; existing roots under customer-corner-root receive one bounded catch-up. No polling, MutationObserver, animation-frame loop, scroll listener, or recurring document walk is added.
Structural selector fixtures and runtime JavaScript tests validate the implementation, not the device appearance. The archived probes describe v7.633, not the newly rendered v7.634. FULL capture receipts say completed but cross-frame completeness remains unverified/best-effort. Hidden menus not represented by the archive are not proven covered. On-device visual confirmation remains necessary.
Existing v7.633 Search/PDP fast paths, C++98 cache fix, Lists/Registry repairs, and probe transport logic are retained. Probe changes in this release are version identities only.
