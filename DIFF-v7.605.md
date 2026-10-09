# AmazonDark v7.605 — sustainability card corner repair

Parent: v7.604, including its previous HOC divider/chevron, sponsored video and similar-product price/icon adjustments and all inherited older fixes.

- VIEWPORT r4 recorded `#sustainability #climatePledgeFriendly .a-box.cpf-dpx-bottom-sheet-carousel-inner` with a **1px #494d4d border and 15px radius**. Its 398x156 `.a-box-inner` paints opaque OLED black with an **8px radius** over that border's corner pixels. The supplied screenshot shows the four arcs disappearing while straight edges remain.
- On this **exact owner only**, set the nested existing `.a-box-inner` **background transparent**, allowing the parent OLED black to provide the floor and its already-authored gray rounded border to show fully; disable inner box shadow.
- No extra borders, pseudo-elements, radius/width/height/padding alterations, document walkers, mutation observers, or probes changed. The blue ClimateCo link, certificate image, and white text remain untouched.
- The fix is added as a tiny `ADSustainabilityBorder7605.js` inclusion after v7.604, preserving earlier rules.
- On-device visual check is still required; the available r4 capture predates this code.
