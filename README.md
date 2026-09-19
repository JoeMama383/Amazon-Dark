# AmazonDark v7.423 — Cart and BYG UI repairs

Based on GitHub 72196f8 / v7.422. The confirmed Returns/Medical Care fixes are inherited unchanged.

- Cart messages banner: OLED outer/inner background, light heading/chevron; preserve authored blue border and thick left rail.
- Cart action row: white share and three-dot image glyphs; three-dot control gray fill/border with dark pressed/focus state; preserve geometry.
- Need anything else / Buy again: exact speed-carousel description panels and sponsored spacers OLED; clear add-to-cart-section/add-to-cart-button wrappers behind the gray circular + controls. Preserve existing neutral light text, authored semantic red/green/blue text, Prime artwork, product images, and steppers.

Eight static CSS rules added to existing programs; no new hooks/scripts/observers/timers/scans. FULL, VIEWPORT and TRANSITION regenerated to v7.423. See COMMANDS.md.
