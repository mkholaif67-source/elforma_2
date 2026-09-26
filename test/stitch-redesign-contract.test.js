'use strict';

const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');

const auth = read('mobile/lib/screens/auth_screen.dart');
const api = read('mobile/lib/api.dart');
const home = read('mobile/lib/screens/home_screen.dart');

const header = read('mobile/lib/widgets/auth_reference_header.dart');
assert(auth.includes('final headerHeight ='), 'auth header must remain keyboard-aware');
assert(auth.includes('296.0') && auth.includes('176.0'), 'headers must match the supplied login and registration designs');
assert(header.includes('Radius.circular(36)'), 'auth header needs the supplied lower corner radius');
assert(header.includes("'assets/auth/reference_logo.png'"), 'auth must use the supplied logo');
assert(!auth.includes('bottom_login.png'), 'legacy foliage footer must not return');
assert(!auth.includes('bottom_signup.png'), 'legacy foliage footer must not return');
assert(!auth.includes('_AuthBackdropPainter'), 'legacy backdrop painter must not control the new design');
assert(!auth.includes('_AuthHeroWaveClipper'), 'legacy wave clipper must not override Stitch geometry');
assert(auth.includes('bool _rememberMe = true;'), 'login must expose the Stitch remember-me control');
assert(auth.includes('remember: _rememberMe'), 'remember-me must affect session persistence');

const phone = auth.slice(auth.indexOf('Widget _phoneField()'), auth.indexOf('Widget _primaryButton()'));
assert(phone.includes('textDirection: TextDirection.rtl'), 'country selector must be physically right of the phone input');

const homeVisuals = read('mobile/lib/widgets/home_dashboard_widgets.dart');
assert(homeVisuals.includes("'assets/logo_lockup.png'"), 'home header must use the supplied white logo');
assert(home.includes("'assets/workout/workout_plan_hero.webp'"), 'workout card must use a local image');
assert(!home.includes('Posterior Workout Gym Session'), 'image fallback text must never appear behind the workout card');
assert(homeVisuals.includes("TextDirection.ltr"), 'numeric progress must preserve count/target order');

assert(api.includes("static const _installMarkerKey = 'ef_install_marker_v1';"), 'reinstall detection is missing');
assert(api.includes('iOS Keychain can survive uninstall'), 'reinstall session isolation must stay documented');
assert(/cookie\s*==\s*null\s*\|\|\s*!remember/.test(api), 'unchecked remember-me must not persist the credential');

console.log('Stitch redesign and account-isolation source contract passed');