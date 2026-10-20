# Stylesheet source layout

`styles/*.css.in` contains 193 extracted stylesheet blocks. The filenames identify the original menu/module. These are source templates: retain existing JavaScript string escapes, interpolation and native preference placeholders such as `__FACTOR__` or `%.3f`. They are compiled into the same strings as before; no file loading or Python execution occurs inside Amazon.

`runtime/Tweak.xm.in` holds the native implementation template. `runtime/payloads/` holds its web programs with stylesheet references. The other `runtime/*.js.in` files hold modular installers and lifecycle logic. Plain `.js` modules without extracted stylesheet blocks remain in `src/`.

Edit the template or stylesheet, then run:

```sh
python3 scripts/build-style-sources.py
AD_STRICT_VALIDATE=1 sh scripts/validate.sh
```

The generated `src/Tweak.xm`, covered `.js` files, and `.js.inc` includes are committed for Theos and phone builds. `--check` rejects drift; CI tests the generated compiler inputs. `styles/manifest.json` maps sources and retains the previous C-string boundaries so native diffs stay reviewable.

Search/product documents install static sheets through `ADRenderScope7640.js`. There is no production review MutationObserver. Ordinary theme installation on these routes must not query document content, read computed layout, register medical shadow hooks, or insert owned STYLE nodes into the live document. Unsupported constructed-sheet APIs use the existing STYLE fallback to preserve paint.

Other routes still have legacy one-shot classifiers and component shadow-root hooks. They are explicitly reported by `scripts/performance-source-audit.py`; they have not been silently relabeled as static CSS or diagnostics. Opt-in FULL/transition/performance recorders remain separate and inactive until armed.
