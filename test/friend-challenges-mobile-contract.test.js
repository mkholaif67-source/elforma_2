'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict');
const read=p=>fs.readFileSync(p,'utf8');
let checks=0;function test(name,fn){fn();checks++;console.log('PASS',name);}
const screen=read('mobile/lib/screens/friend_challenges_screen.dart');
const api=read('mobile/lib/api.dart');
const links=read('mobile/lib/community_links.dart');
const manifest=read('mobile/android/app/src/main/AndroidManifest.xml');
const activity=read('mobile/android/app/src/main/kotlin/com/elforma/elforma/MainActivity.kt');
const community=read('mobile/lib/screens/community_screen.dart');
test('friend challenge center exposes create and join paths',()=>{assert.match(screen,/class FriendChallengesScreen/);assert.match(screen,/تحدي جديد/);assert.match(screen,/انضم بكود/);});
test('personal challenge can start a separate friends challenge',()=>{assert.match(community,/FriendChallengeEditor\(personal: p\)/);assert.match(community,/تحدي اصحابك/);});
test('member invitation and owner approval controls are present',()=>{assert.match(screen,/دعوة صاحب/);assert.match(screen,/طلبات الانضمام/);assert.match(screen,/'approve': true/);assert.match(screen,/'approve': false/);});
test('privacy copy stays simple and avoids internal terms',()=>{assert.match(screen,/تفاصيل الوجبات والقياسات والملاحظات الخاصة لا تظهر للمشاركين/);for(const term of ['API','Backend','Deep Link','database','schema'])assert(!screen.includes("Text('"+term));});
test('API reads are cached and daily logging can queue offline',()=>{assert.match(api,/friendChallenges\(\)/);assert.match(api,/friendChallengeDetail/);assert.match(api,/friendChallengeAction/);assert.match(screen,/queue: true/);assert(api.match(/'\/api\/mobile\/friend-challenges'/g).length>=2);});
test('Android accepts verified web links and safe custom fallback links',()=>{assert.match(manifest,/android:autoVerify="true"/);assert.match(manifest,/android:host="elforma\.onrender\.com"/);assert.match(manifest,/android:host="friend-challenge"/);assert.match(activity,/elforma\/links/);assert.match(activity,/override fun onNewIntent/);assert.match(links,/FriendChallengePreviewScreen/);});
test('existing official and personal screens remain present',()=>{assert.match(community,/class ChallengeScreen/);assert.match(community,/class ChallengeEditor/);assert.match(community,/تحديات فريق الفورمة/);assert.match(community,/تحدياتك الشخصية/);});
console.log(`${checks} friend challenge mobile contract checks passed`);
