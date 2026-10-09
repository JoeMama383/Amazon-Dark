(function(){try{
var d=document,s=d.getElementById('ad7605-sustainability-border-corners');
if(!s){s=d.createElement('style');s.id='ad7605-sustainability-border-corners';(d.head||d.documentElement||d).appendChild(s);}
/* v7.602 VIEWPORT r4 observed Amazon's original sustainability box at
   #sustainability > #climatePledgeFriendly:
   outer .cpf-dpx-bottom-sheet-carousel-inner: 400x158, 1px #494d4d,
   radius 15px, OLED black. Its inner .a-box-inner: 398x156,
   OLED black and radius 8px. The smaller-radius *opaque child* can
   overpaint the already drawn curved outer-border corners, leaving four
   visible gaps. Make only the existing child backing transparent. The
   outer element already paints OLED black and owns the original border.
   Do not change either radius, border, padding, or add pseudo-borders. */
s.textContent=`
#dp#dp #sustainability #climatePledgeFriendly .a-box.cpf-dpx-bottom-sheet-carousel-inner > .a-box-inner{
 background:transparent!important;
 box-shadow:none!important;
}
`;
}catch(_){}})();
