# AmazonDark v6.0.199 — restore WebKit Dark Reader bootstrap

Production correction built on v6.0.198 probe evidence. The native preferences were enabled, but the live Amazon WKWebView had no `__AMZDARK_LOADED__`, no `DarkReader`, no apply/wake functions, and zero Dark Reader styles. v6.0.199 hardens runtime Dark Reader resource resolution for rootless/preboot installs and replaces the one-shot self-heal gate with a missing-engine-only, per-WebView single-flight recovery. Probe capture observers from v6.0.198 are disabled in production.
