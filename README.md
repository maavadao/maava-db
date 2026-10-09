# maava-db

The shared Postgres schema for maava: users, tenants, agents, community content,
marketplace, channels, provider keys, inbox and more. The website, dashboard, API, auth,
channels and skills services all use this database. Mission Control and the platform service
manage their own schemas.

Part of [maava](https://github.com/maavadao/maava), the open-source agent platform behind maavaDao: a community-owned ecosystem of agentic AI for education, where developers build and list agents for free and the community shares in what they earn.

## Apply the migrations

Requires `psql` and a Postgres 16 database.

```bash
export DATABASE_URL=postgresql://postgres:postgres@localhost:5432/maavadao
scripts/migrate.sh
```

The script applies `migrations/*.sql` in filename order and records each file in
`schema_migrations`, so running it again only applies new files. For a throwaway local database:

```bash
docker run -d --name maavadao-db -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=maavadao -p 5432:5432 postgres:16
```

## Adding a migration

- Add a new file with the next number, for example `038_add_widgets.sql`. Never edit a migration that has been released.
- Make it safe to re-run where you can (`IF NOT EXISTS`, `IF EXISTS`).
- Tables with row-level security use the `app.current_user_id` setting; follow `015_row_level_security.sql`.
- CI applies every migration to an empty database twice. Run `scripts/migrate.sh` locally first.

## Contributing

Read the [contributing guide](https://github.com/maavadao/maava/blob/main/CONTRIBUTING.md) before opening a pull request.
Work lands on `main`; releases are tagged `vX.Y.Z` as described in [RELEASING.md](https://github.com/maavadao/maava/blob/main/RELEASING.md).

## Licence

Apache 2.0. See [LICENSE](LICENSE).
