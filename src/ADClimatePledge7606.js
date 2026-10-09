(function(){try{
var d=document,s=d.getElementById('ad7606-climate-pledge-friendly');
if(!s){s=d.createElement('style');s.id='ad7606-climate-pledge-friendly';(d.head||d.documentElement).appendChild(s);}
/* v7.602 VIEWPORT r5/r6/r7: this is the Octopus browse document containing
   .apb-default-category-drilldown (Climate Pledge Friendly destination),
   NOT the parent PDP sustainability card. No generic Amazon page overrides. */
s.textContent=`
/* OLED shell and authored 1px section dividers (formerly white). */
#a-page .octopus-page-style:has(.apb-default-category-drilldown){background:#000!important;color:#fff!important;}
#a-page .octopus-page-style:has(.apb-default-category-drilldown) :is(.border-top-1px,.border-bottom-1px){border-color:#494d4d!important;}
#a-page .octopus-page-style:has(.apb-default-category-drilldown) :is(hr,.a-divider-normal){border-color:#494d4d!important;background-color:#494d4d!important;}
/* Tame actual raster imagery, including certification montage, illustrated
   leaf/hero panels and Climate Pledge logo; keep green branding, no inversion. */
#a-page .octopus-page-style:has(.apb-default-category-drilldown) img{
 filter:brightness(__FACTOR__)!important;-webkit-filter:brightness(__FACTOR__)!important;
 mix-blend-mode:normal!important;
}
/* An independently observed hero uses a CSS background image instead of img.
   Multiply only the background paint, not white headings atop it. */
#a-page .octopus-page-style:has(.apb-default-category-drilldown) .bg-no-repeat{
 background-color:#777!important;background-blend-mode:multiply!important;
}
/* The probed category card's outer 402x1276 .a-box.a-vertical is white;
   recolor its EXISTING 1px #d5d9d9 perimeter, do not add a second border. */
#a-page .octopus-page-style .apb-default-category-drilldown>.a-box.a-vertical{
 background:#000!important;border-color:#747a7c!important;color:#fff!important;
}
#a-page .octopus-page-style .apb-default-category-drilldown>.a-box.a-vertical>.a-box-inner{
 background:transparent!important;
}
#a-page .octopus-page-style .apb-default-category-drilldown .a-box-list li{
 background:#000!important;border-bottom-color:#494d4d!important;color:#fff!important;
}
#a-page .octopus-page-style .apb-default-category-drilldown .a-box-list a.a-touch-link{
 background:#000!important;color:#fff!important;-webkit-text-fill-color:#fff!important;
}
#a-page .octopus-page-style .apb-default-category-drilldown .a-box-list a.a-touch-link .a-box-inner,
#a-page .octopus-page-style .apb-default-category-drilldown .a-box-list a.a-touch-link .a-box-inner :is(span,b,strong){
 background:transparent!important;color:#fff!important;-webkit-text-fill-color:#fff!important;
}
/* 2px CSS-border chevrons (viewport r5) were rgb(15,17,17). */
#a-page .octopus-page-style .apb-default-category-drilldown i.a-icon-touch-link{
 color:#fff!important;border-color:#fff!important;
}
`;
}catch(_){}})();
