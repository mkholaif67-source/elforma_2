# ElForma — Start Here

This is the active documentation set for the current project. Markdown files are for humans and tools; they are not bundled into the Flutter app.

## Source map

- Mobile app: `mobile/lib/`, `mobile/assets/`, `mobile/pubspec.yaml`
- Backend: `server.js`, `api/`, `lib/`
- Nutrition engine: `app/diet/js/`
- Workout engine: `app/workout/engine/`
- Web/admin: `public/`, `app/`
- Tests: `test/`

## First commands

```bash
npm install
npm run test:all
npm start
```

For mobile validation:

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Read `01_CURRENT_STATUS.md` before changing production code.
