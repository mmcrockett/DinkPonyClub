# Moving production's primary database from MySQL to SQLite

Every query to the shared MySQL host costs ~57ms, so the primary lives in `storage/production.sqlite3` on the Docker volume and MySQL (`mysql_backup`) is an hourly copy.

## Cutover

1. Deploy the branch with `League::DatabaseCopy` and the `sqlite_primary` config (still reading MySQL). Boot-time `db:prepare` creates and migrates the empty SQLite file.
2. Pick a quiet time. In the web container run `FROM=primary TO=sqlite_primary bin/rails db:sync:copy` and check the printed row counts against MySQL.
3. Deploy the branch that makes `primary` the SQLite file and adds `mysql_backup` plus `DatabaseBackupJob`. Writes made to MySQL after step 2 are not carried over, so keep the window short.
4. After the first `DatabaseBackupJob` run (minute 42), check the log line `DatabaseBackupJob: copied in ...` has the same counts as the app. The admin dashboard shows a backup warning from deploy until that first run succeeds, and again whenever no successful copy has been recorded in 3 hours.

## Restore after losing the volume

Deploy as normal (boot creates and migrates an empty SQLite file), then run `FROM=mysql_backup TO=primary bin/rails db:sync:copy`. Writes since the last hourly run are lost.

Do this before the next minute-42 run. `DatabaseBackupJob` refuses to copy a completely empty primary over a populated backup, but it cannot tell a nearly empty primary from a real one, so if the restore will be delayed, remove `backup_database_to_mysql` from `config/recurring.yml` and redeploy first.

## Rollback

Run `FROM=primary TO=mysql_backup bin/rails db:sync:copy`, then deploy a `database.yml` whose `primary` is the MySQL url.
