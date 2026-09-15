'use strict';
function effectiveMealCount(requested,target){return Number(requested)===2&&Number(target)>2200?3:Number(requested)||3;}
function portionMax(entry){
 const f=entry.food||entry,n=String(f.nameAr||f.name||''),cat=String(f.cat||'');
 if(require('./nutrition-owner-policy').isCookedVeg(entry))return 200;
 if(/أرز|ارز|(?:^|\s)رز|مكرونة|مكرونه|بطاطس/.test(n))return 400;
 if(/سلطة/.test(n))return 300;
 if(cat==='salad_veg'||(/veg/.test(cat)&&!/مطبوخ|مخلل|شوربة/.test(n)))return 100;
 return Infinity;
}
module.exports={effectiveMealCount,portionMax};
