# Active Project Rules

1. Nutrition truth stays in `app/diet/js/`; workout truth stays in `app/workout/engine/`.
2. User cache keys, offline queues, and in-flight requests must remain account-scoped.
3. Every write invalidates its related read cache.
4. Subscription/entitlement reads must not authorize from stale cache.
5. Keep `EF_SECRET` stable and production storage durable.
6. Keep `EF_TURSO_MODE=remote` unless a separately tested replica migration exists.
7. Stop polling timers when the app is backgrounded; `TickerMode` alone is not enough.
8. Use `cacheWidth`/`cacheHeight` for rendered images and stop finished animations.
9. Preserve RTL, scalable text, explicit contrast, and accessibility semantics.
10. Keep `package.json`, `mobile/pubspec.yaml`, and `mobile/lib/api.dart` versions synchronized.
11. Source/UI text must contain zero `U+FFFD` characters.
12. Run the full test gate before release. Do not claim Flutter validation without Flutter installed.
