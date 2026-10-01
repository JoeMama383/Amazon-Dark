# v7.541 — Logos build repair for legacy keyboard clamp

The v7.540 CI compile failure is caused by one Logos-specific source form in the `UITextInputTraits` getter:

`UIKeyboardAppearance a=%orig,next=...;`

For a bare `%orig`, Logos replaces the directive through the end of its source line. That means the generated Objective-C++ keeps the original-call assignment but discards the comma and `next` declaration. The following trace and return then reference an undeclared `next`, producing the two compiler errors seen before the retain-cycle warnings.

v7.541 makes the same logic Logos-safe:

- `UIKeyboardAppearance a=%orig;`
- `UIKeyboardAppearance next=...;` on the next line

No keyboard ownership or UI behavior is removed. The legacy getter still returns Dark while AmazonDark is enabled, the setter still forwards Dark, the expanded transition trace remains intact, and the extended-traits coverage remains available for newer WebKit. No modal CSS or geometry changes are included.
