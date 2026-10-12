# AmazonDark 7.633 — probe/screenshot UI change log

**Parent:** official v7.633 `web-cache-cpp98-compatibility`. Retains original v7.631 checkout-only Search/PDP fast-path and the v7.633 portable gnu++98 fixture fix.

**New WebKit module:** `src/ADListsRegistry7633.js` and exact UTF-8 `src/ADListsRegistry7633.js.inc`, emitted from the existing late menu WebKit injection source. Declarative document-start CSS, one stylesheet (idempotent), no scheduled scans, DOM walking, mutations, UI element insertion, or geometry rewriting. Styles only exact page DOM probe anchors.

**Covered WebKit menu ownership:**
- Lists & Registry list cards: `#wishlistAndFriendsLists`, `#awl-lol-lists-header`, `#awl-lol-your-lists-tab-content`; white cards to dark neutral, neutral labels white/gray and links remain blue.
- Your Saves/Add content modal: `#external-saves-add-content-content` and `.a-sheet-web`, OLED sheet, white icons/text, gray authored dividers. Includes Photo, Link, Note, Create new list.
- Create List sheet: `#createlist-form-container`; OLED white labels, neutral input, black/white/gray bordered create button, authored link colors preserved.
- Shopping List detail: `.awl-list-view-page-container`, `#wl-item-view`, `#awl-list-items`, `[id^=item_title_]`, `[id^=pab-]`, overflow menu buttons; restores white/gray text, OLED/gray buttons, gray dividers; preserves stars, Prime blue, warning red, product images, and optional leaf-level image brightness (TWB).
- Independent OMG multi-add screen: `body.omg-body`, `#omg-matc-top-section-id`, `#reorderSection`; OLED/neutral text and Add to Cart controls.

**Native grocery/Shopping List repair:**
- React anchors from the supplied native captures: `nglHomePageIngress`, `Recommendation_container`, `recommendedTabView`, `recipeManagementHomePage`, `header_text_alexa_for_shopping`, `addToListButton`.
- Existing RCTView mount/layout and background setter intercept now recolor owned near-white surfaces OLED or dark gray and user-action Add Item controls OLED/gray-bordered, including the native probe-confirmed 410 x 53.7 pt orange button via a shopping-owner-guarded color/size predicate. No mutation/observer/extra controls.
- Existing RCTTextView commit and final draw paths now repair dark-on-dark neutral text but leave saturated/brand colors intact.
- Route ownership stops before shared navigation root / React root content: avoids leaking grocery colors to unrelated menus.

**Not changed:** universal FULL/VIEWPORT/TRANSITION probes, Search/PDP performance fast-path, layout dimensions, scrolling, product imagery visibility, review/color glyph families, rootless Theos packaging conventions.

**Important limitation:** Screenshots depict additional native delivery-address and Alexa Shopping List title-bar surfaces whose precise view IDs did not appear in the nine archival probes. Existing location/Alexa owners are retained; the screenshot-only fallback cannot be guaranteed fixed without a same-menu native UI probe after installation. This is deliberately not “fixed” using guessed global UIView rules that would regress other screens.
