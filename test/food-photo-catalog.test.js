'use strict';
const assert=require('node:assert/strict');const fs=require('node:fs');const path=require('node:path');
const root=path.join(__dirname,'..');const dir=path.join(root,'mobile/assets/food_photos');
const files=fs.readdirSync(dir);const webp=files.filter(x=>x.endsWith('.webp'));
assert.equal(files.filter(x=>x.endsWith('.png')).length,0,'legacy multi-megabyte PNGs must stay removed');
assert(webp.length>=37,'expanded catalogue must keep at least 37 exact food photos');
for(const file of webp){const b=fs.readFileSync(path.join(dir,file));assert.equal(b.subarray(0,4).toString(),'RIFF');assert.equal(b.subarray(8,12).toString(),'WEBP');}
const art=fs.readFileSync(path.join(root,'mobile/lib/widgets/meal_art.dart'),'utf8');
for(const key of ['apple','banana','rice','bread_baladi','pasta','potato','sweet_potato','salad','tuna','lentil_soup','dates','nuts','popcorn','dark_chocolate','kofta','liver','cooked_vegetables','milk','coffee','mackerel','sardines','mullet','fried_eggs','omelette','turkey','white_cheese','roumy_cheese','legumes']) assert(art.includes("_Rule('"+key+"'") || art.includes("_Rule(\n    '"+key+"'"),key+' mapping missing');
assert(art.includes("assets/food_photos/$key.webp"));
// Every asset referenced by a Dart mapping must exist. This catches a typo that
// otherwise degrades silently to the neutral placeholder through errorBuilder.
const referenced=[...art.matchAll(/_Rule\(\s*'([^']+)'/g)].map(match=>match[1]);
for(const key of new Set(referenced)) assert(fs.existsSync(path.join(dir,key+'.webp')),key+' mapped asset missing');
// Regression guards for the three display bugs reported against real engine
// names: NBSP variants must normalize, composite dishes must win before their
// ingredients, and the egg stem must be word-anchored so أبيض is never eggs.
assert(art.includes("replaceAll(_nonWord, ' ').trim()"),'food-name whitespace normalization missing');
assert(art.indexOf("_Rule('salad'")<art.indexOf("_Rule('tomato'"),'salad must outrank tomato');
assert(art.indexOf("_Rule('rice'")<art.indexOf("_Rule('eggs'") || art.includes("'بيض',"),'rice/egg collision guard missing');
assert(art.includes("'بيض',") && art.includes('_anchored.contains(pattern) ? _word(pattern) : pattern'),'egg word boundary guard missing');
for(const screen of ['food_picker_screen.dart','pantry_screen.dart','meal_plan_screen.dart']) assert(fs.readFileSync(path.join(root,'mobile/lib/screens',screen),'utf8').includes('FoodPhoto('),screen+' photo binding missing');
console.log('food photo catalogue: '+webp.length+' compact WebP assets and nutrition bindings passed');
