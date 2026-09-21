# AmazonDark v7.438 audit — compile fix

Exact parent: v7.437 `pdp-standalone-ad-treatment`.

Fixes two source defects exposed by GitHub Actions:

- Search sponsored-results CSS contained unescaped double quotes inside an Objective-C string literal. The CSS attribute value now uses single quotes, preserving the exact selector while restoring valid Objective-C syntax.
- `ADCheckoutTWBJS7369` contains eight `%.3f` conversions but only six `factor` arguments. v7.438 supplies all eight arguments, removing the format warning and preventing undefined formatting behavior.

No theming selectors or runtime architecture are otherwise changed from v7.437.
