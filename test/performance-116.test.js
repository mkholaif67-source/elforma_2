'use strict';
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '..');
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
let passed = 0;
function test(name, fn) {
  try { fn(); passed++; console.log('✓ ' + name); }
  catch (error) { console.error('✗ ' + name); throw error; }
}

const main = read('mobile/lib/main.dart');
const splash = read('mobile/lib/screens/splash_screen.dart');
const shell = read('mobile/lib/screens/shell_screen.dart');
const meal = read('mobile/lib/screens/meal_plan_screen.dart');
const api = read('mobile/lib/api.dart');
const sub = read('mobile/lib/models/subscription_store.dart');
const notif = read('mobile/lib/notification_service.dart');
const workout = read('mobile/lib/screens/workout_screen.dart');

test('first frame is painted before non-critical service warmup', () => {
  assert(main.indexOf('runApp(const ElFormaApp())') < main.indexOf('unawaited(_warmStartupServices())'));
  assert(!main.slice(main.indexOf('Future<void> main()'), main.indexOf('Future<void> _ignoreStartup')).includes('await ExerciseVideoCatalog'));
});

test('essential local services remain present', () => {
  for (const token of ['ExerciseVideoCatalog.I.load', 'SmartCoachStore.I.init', 'ConnectivityService.I.init', 'NotificationService.I.initialize', 'BackgroundPoll.setup']) assert(main.includes(token), token);
});

test('api initialization is shared across concurrent callers', () => {
  assert(api.includes('Future<void>? _initInFlight'));
  assert(api.includes('if (active != null) return active'));
  assert(api.includes('_initialized = true'));
});

test('splash runs independent network checks concurrently', () => {
  assert(splash.includes('Future.wait<dynamic>'));
  assert(splash.includes('UpdateGate.check()'));
  assert(splash.includes('Api.I.me()'));
  assert(!splash.includes('Duration(milliseconds: 500)'));
});

test('profile warmup no longer blocks shell navigation', () => {
  assert(splash.includes('unawaited(ProfileStore.I.ensureLoaded(force: true))'));
  assert(splash.includes('gate.maintenance'));
  assert(splash.includes('UpdateVerdict.required'));
});

test('main tabs are created lazily and kept alive', () => {
  assert(shell.includes('List<Widget?>.filled(4, null)'));
  assert(shell.includes('_pages[i] ??= _buildPage(i)'));
  assert(shell.includes('IndexedStack'));
  assert(!shell.includes('final pages = ['));
});

test('all four destinations remain wired', () => {
  for (const token of ['HomeScreen(', 'WorkoutScreen()', 'MealPlanScreen()', 'AccountScreen()']) assert(shell.includes(token), token);
  assert.strictEqual((shell.match(/NavigationDestination\(/g) || []).length, 4);
});

test('shell shares bootstrap with subscription startup', () => {
  assert(shell.includes('SubscriptionStore.I.init(seed: bootstrap.ok'));
  assert(!shell.includes('SubscriptionStore.I.init();'));
  assert(sub.includes('Future<void> init({Map<String, dynamic>? seed})'));
  assert(sub.includes('bool _pollingStarted = false'));
});

test('subscription refresh still forces fresh state after changes', () => {
  assert(sub.includes('mobileBootstrap(force: true)'));
  assert(sub.includes("sub['canExport'] == true"));
  assert(sub.includes("sub['active'] == true"));
});

test('nutrition plan and bootstrap load concurrently', () => {
  assert(meal.includes('Future.wait<ApiResult>'));
  const block = meal.slice(meal.indexOf('Future.wait<ApiResult>'), meal.indexOf('if (!mounted) return;', meal.indexOf('Future.wait<ApiResult>')));
  assert(block.includes('nutritionPlan('));
  assert(block.includes('mobileBootstrap()'));
});

test('read timeout is bounded while writes keep cold-start tolerance', () => {
  assert(api.includes("method == 'GET'"));
  assert(api.includes('Duration(seconds: 25)'));
  assert(api.includes('Duration(seconds: 70)'));
  assert(api.includes("'/api/mobile/bootstrap'"));
  assert(api.includes('fromCache'));
});

test('bootstrap still invalidates after persisted plan changes', () => {
  assert(api.includes('void invalidateBootstrap()'));
  assert(workout.includes('Api.I.invalidateBootstrap()'));
});

test('notification initialization is deduplicated safely', () => {
  assert(notif.includes('Future<void>? _initializeInFlight'));
  assert(notif.includes('final future = _initializeOnce()'));
  assert(notif.includes('if (_ready) return Future.value()'));
});

test('release versions are synchronized', () => {
  assert.strictEqual(require(path.join(root, 'package.json')).version, '1.0.16');
  assert(read('mobile/pubspec.yaml').includes('version: 1.0.16+66'));
  assert(api.includes('const int kAppBuild = 66'));
  assert(api.includes("const String kAppVersionName = '1.0.16'"));
});

console.log(`performance-116: ${passed} passed, 0 failed`);
