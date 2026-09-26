# Configuration

## Production secrets

Keep these in the hosting provider, never in Git:

- `EF_SECRET` — session signing; keep stable or all sessions are invalidated.
- `TURSO_DATABASE_URL` and `TURSO_AUTH_TOKEN` — durable database.
- `EF_MAIL_API_URL`, `EF_MAIL_API_KEY`, `EF_MAIL_FROM` — production email.
- `EF_ADMIN_EMAILS` — verified admin allowlist.

## Runtime settings

- Production database: `EF_DATABASE_ENGINE=turso` and `EF_TURSO_MODE=remote`.
- Local development: SQLite is acceptable; production local SQLite needs durable storage.
- `NODE_OPTIONS=--experimental-sqlite` is required by the current Node path.
- `EF_REQUIRE_DURABLE_DB=1` prevents unsafe production startup.

## Mobile API URL

The mobile server URL is a build-time value:

```bash
flutter build apk --release --dart-define=EF_BASE_URL=https://your-domain.example
```

Changing the API domain requires a new mobile build unless a stable custom API domain is used.

Never commit `.env`, database files, signing keys, service-account files, or Firebase secrets.
