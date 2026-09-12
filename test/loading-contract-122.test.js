'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs');
const read=p=>fs.readFileSync(require('node:path').join(__dirname,'..',p),'utf8');
let n=0;function check(name,fn){fn();n++;console.log('PASS '+name);}
const api=read('mobile/lib/api.dart'),profile=read('mobile/lib/models/profile_store.dart'),analysis=read('mobile/lib/screens/analysis_screen.dart'),editor=read('mobile/lib/screens/profile_overview_screen.dart'),workout=read('mobile/lib/screens/workout_screen.dart');
check('profile load registers shared future before notifying any listener',()=>{assert(profile.indexOf('_inFlight = shared;')<profile.indexOf('unawaited(_load(force: force)'));assert(profile.includes('Completer<void>()'));});
check('profile forced refresh propagates to bootstrap',()=>assert(profile.includes('mobileBootstrap(force: force)')));
check('mutation invalidates persistent reads and in-flight generations',()=>{assert(api.includes('_epoch++'));assert(api.includes('sp.remove(key)'));assert(api.includes('requestEpoch != _epoch'));assert(api.includes('sessionEpoch != _sessionEpoch'));});
check('cached responses are deep-copied, date-scoped and not used as current online reads',()=>{assert(api.includes('jsonDecode(jsonEncode(r.data))'));assert(api.includes('substring(0,10)'));assert(!api.includes('unawaited(_refreshBootstrapNetwork())'));});
check('analysis does not secretly run a second workout generator',()=>{assert(!analysis.includes('_prepareWorkoutPlan'));assert(!analysis.includes('workoutCompute('));assert(!analysis.includes('await historyFuture'));assert(analysis.includes('_profileSaved'));assert(analysis.includes('finally'));});
check('stage text is factual, no timer cycling or overlapping outgoing labels',()=>{assert(!analysis.includes('_stepTimer'));assert(analysis.includes('layoutBuilder: (current, previous)'));assert(!analysis.includes('خطتك جاهزة يا بطل'));});
check('direct field editor submits partial patches, distinct from explicit redo',()=>{assert(editor.includes('_editField'));assert(editor.includes('patch:true'));assert(editor.includes('TextField(controller:controller'));assert(editor.includes('RadioListTile<String>'));assert(editor.includes('CheckboxListTile'));assert(editor.includes('_redo()'));});
check('workout has re-entry guard, retry and saved-plan refresh detection',()=>{assert(workout.includes('_generating'));assert(workout.includes('_needsProfileRefresh'));assert(workout.includes('MaterialBanner'));assert(workout.includes('finally'));});
check('completed questionnaire has no internal summary speech',()=>assert(!read('mobile/lib/screens/profile_setup_screen.dart').includes('تمام يا بطل خلصنا التعارف')));
check('new-user completion repaints the gate even when profile values are unchanged',()=>{
 const callback=workout.slice(workout.indexOf('  void _onProfileChanged()'),workout.indexOf('  Future<void> _boot()'));
 assert(callback.indexOf('setState(() {});')>=0);
 assert(callback.indexOf('setState(() {});')<callback.indexOf('if(signature==_lastProfileSignature)return;'));
 const boot=workout.slice(workout.indexOf('  Future<void> _boot()'),workout.indexOf('  Future<void> _openSetup()'));
 assert(boot.includes('setState(() {});'));
});
console.log(`loading-contract-122: ${n} source checks passed (not Flutter runtime tests)`);
