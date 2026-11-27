param(
    [string]$Db     = "sports_db",
    [string]$PgUser = "postgres",
    [string]$PgHost = "localhost",
    [int]   $PgPort = 5432
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "== Пересоздание базы $Db ==" -ForegroundColor Cyan

dropdb --if-exists -h $PgHost -p $PgPort -U $PgUser $Db
if ($LASTEXITCODE -ne 0) { throw "dropdb завершился с ошибкой" }

createdb -h $PgHost -p $PgPort -U $PgUser -E UTF8 -T template0 $Db
if ($LASTEXITCODE -ne 0) { throw "createdb завершился с ошибкой" }

psql -h $PgHost -p $PgPort -U $PgUser -d $Db -v ON_ERROR_STOP=1 -f (Join-Path $here "01_schema.sql")
if ($LASTEXITCODE -ne 0) { throw "01_schema.sql завершился с ошибкой" }

psql -h $PgHost -p $PgPort -U $PgUser -d $Db -v ON_ERROR_STOP=1 -f (Join-Path $here "02_data.sql")
if ($LASTEXITCODE -ne 0) { throw "02_data.sql завершился с ошибкой" }

Write-Host "== Готово ==" -ForegroundColor Green
