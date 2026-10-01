## v7.541 — legacy keyboard clamp build repair

Direct parent: v7.540.

The expanded v7.539 transition evidence still stands: iOS 17.0 uses the legacy `UITextInputTraits` path during the Interests editor handoff, and fresh legacy traits can report `UIKeyboardAppearanceDefault` after the keyboard initially appears dark. v7.540 correctly targeted that path, but its getter placed a second declaration after a bare Logos `%orig` on the same source line. Logos replaces a bare `%orig` from the directive through the end of that line, so the generated Objective-C++ lost the `next` declaration and the Theos build failed with two undeclared-identifier errors.

v7.541 preserves the exact v7.540 keyboard behavior and changes only the Logos-safe statement layout: `%orig` terminates its own statement, then the dark-clamp variable is declared on the following line. No modal paint/geometry, keyboard behavior, probe behavior, or production runtime architecture is otherwise changed.
