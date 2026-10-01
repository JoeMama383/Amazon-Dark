## v7.542 — keyboard consumer transition probe

Direct parent: v7.541.

The v7.541 production clamp builds correctly but does not stop the Interests keyboard from changing from the correct OLED appearance to light keycaps after presentation. The v7.539 evidence isolated a legacy traits reset, but v7.541 proving ineffective means that reset was not the final keycap-selection boundary.

v7.542 is diagnostic-only. Production keyboard and modal behavior remain unchanged. The transition probe now captures the effective UIKit keyboard-consumer state around WillShow/DidShow and for two seconds afterward: first responder, UIKeyboard/UITextEffectsWindow/input-host style state, any available UIKeyboardImpl singleton state, related input/delegate object classes and pointers, and a bounded filtered method inventory. This should tell us whether the switch is caused by UIKit's effective appearance/style, a different input delegate/traits owner, or a state change that occurs only in the remote keyboard process.
