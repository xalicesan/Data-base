param(
    [string]$Db         = "sports_db",
    [string]$PgUser     = "postgres",
    [string]$PgHost     = "localhost",
    [int]   $PgPort     = 5432,
    [string]$PgPassword = ""
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

if ($PgPassword -ne "") { $env:PGPASSWORD = $PgPassword }

Write-Host "== Recreating database $Db ==" -ForegroundColor Cyan

dropdb --if-exists -h $PgHost -p $PgPort -U $PgUser $Db
if ($LASTEXITCODE -ne 0) { throw "dropdb failed" }

createdb -h $PgHost -p $PgPort -U $PgUser -E UTF8 -T template0 $Db
if ($LASTEXITCODE -ne 0) { throw "createdb failed" }

psql -h $PgHost -p $PgPort -U $PgUser -d $Db -v ON_ERROR_STOP=1 -f (Join-Path $here "01_schema.sql")
if ($LASTEXITCODE -ne 0) { throw "01_schema.sql failed" }

psql -h $PgHost -p $PgPort -U $PgUser -d $Db -v ON_ERROR_STOP=1 -f (Join-Path $here "02_data.sql")
if ($LASTEXITCODE -ne 0) { throw "02_data.sql failed" }

Write-Host "== Done ==" -ForegroundColor Green


