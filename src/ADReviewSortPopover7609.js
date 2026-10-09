(function(){try{
var d=document,s=d.getElementById('ad7609-review-sort-popover');
if(!s){s=d.createElement('style');s.id='ad7609-review-sort-popover';(d.head||d.documentElement).appendChild(s);}
/* v7.605 VIEWPORT r4: .a-dropdown.a-dropdown-common popover containing
   .sort-order-option and #sort-order-dropdown_0/_1. Paint ONLY this owner;
   keep its selected blue border and original close sprite/geometry. */
s.textContent=`
#a-popover-2.a-popover.a-dropdown.a-dropdown-common:has(.sort-order-option) .a-popover-wrapper,
#a-popover-2.a-popover.a-dropdown.a-dropdown-common:has(.sort-order-option) .a-popover-header,
#a-popover-2.a-popover.a-dropdown.a-dropdown-common:has(.sort-order-option) .a-popover-inner{
 background-color:#000!important;color:#fff!important;box-shadow:none!important;
}
#a-popover-2.a-popover.a-dropdown.a-dropdown-common:has(.sort-order-option) .a-popover-wrapper{border-color:#747a7c!important;}
#a-popover-2.a-popover.a-dropdown.a-dropdown-common:has(.sort-order-option) :is(.a-popover-header-content,.a-dropdown-link){
 color:#fff!important;-webkit-text-fill-color:#fff!important;
}
#a-popover-2.a-popover.a-dropdown.a-dropdown-common:has(.sort-order-option) .sort-order-option{
 border-color:#494d4d!important;background-color:#000!important;
}
#a-popover-2.a-popover.a-dropdown.a-dropdown-common:has(.sort-order-option) .a-dropdown-link{
 background-color:#000!important;
}
#a-popover-2.a-popover.a-dropdown.a-dropdown-common:has(.sort-order-option) .a-dropdown-link.a-active{
 background-color:#202324!important;border-color:#2162a1!important;
}
#a-popover-2.a-popover.a-dropdown.a-dropdown-common:has(.sort-order-option) .a-button-close .a-icon-close{
 filter:brightness(0) invert(1)!important;-webkit-filter:brightness(0) invert(1)!important;
}
`;
}catch(_){}})();
