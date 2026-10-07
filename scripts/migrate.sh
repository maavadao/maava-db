#!/usr/bin/env bash
# Applies migrations/*.sql in filename order, each once, recording them in schema_migrations.
set -euo pipefail

: "${DATABASE_URL:?DATABASE_URL must be set}"
cd "$(dirname "$0")/.."

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -c \
  "CREATE TABLE IF NOT EXISTS schema_migrations (filename text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())"

for file in migrations/*.sql; do
  name=$(basename "$file")
  applied=$(psql "$DATABASE_URL" -tAq -v name="$name" <<'SQL'
SELECT 1 FROM schema_migrations WHERE filename = :'name'
SQL
)
  [ "$applied" = "1" ] && continue
  echo "applying $name"
  # Files that manage their own transaction run as-is; the rest run in one transaction.
  if grep -qiE '^\s*BEGIN\s*;' "$file"; then
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f "$file"
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -v name="$name" <<'SQL'
INSERT INTO schema_migrations (filename) VALUES (:'name')
SQL
  else
    {
      echo "BEGIN;"
      cat "$file"
      echo
      echo "INSERT INTO schema_migrations (filename) VALUES ('$name');"
      echo "COMMIT;"
    } | psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q
  fi
done
echo "migrations up to date"
