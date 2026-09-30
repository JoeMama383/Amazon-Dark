## v7.534 — WebKit theme parse regression repair

Direct parent: v7.532.

v7.530 introduced a malformed JavaScript escape in `ADNewMenus7482.js.inc` while drawing the Interests contextual-menu ellipsis. The reconstructed payload contained `content:'\22EE'` inside a JavaScript template literal; Node/WebKit reject that escape at parse time. Because `ADNewMenusJS7482()` is appended to the main WebKit theme script, this prevented the complete user script from parsing and caused otherwise unrelated web surfaces to fall back to stock/light rendering.

v7.534 replaces the malformed escape with a literal vertical-ellipsis glyph and retains the intended v7.529/v7.530 Interests fixes: OLED prompt/menu surfaces, white plus, white filled heart, white rating text, OLED Update your Interest sheet, white header/X, and dark keyboard traits. It also adds an executable-payload parse regression.
