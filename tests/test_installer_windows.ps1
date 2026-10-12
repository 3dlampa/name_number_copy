$ErrorActionPreference = 'Stop'

# Genuine Windows cmd.exe integration test, including spaces and Hungarian accents.
$batPath = Join-Path (Get-Location).Path 'telepites.bat'
$sourceExe = Join-Path (Get-Location).Path 'name - number copy.exe'
$destDir = Join-Path $env:RUNNER_TEMP 'telepítés próba - 3d lámpa\Photoshop és Illustrator scriptek'
$destExe = Join-Path $destDir 'name - number copy.exe'

$batBytes = [System.IO.File]::ReadAllBytes($batPath)
$batText = [System.Text.Encoding]::UTF8.GetString($batBytes)
if ([System.Text.Encoding]::UTF8.GetByteCount($batText) -ne $batBytes.Length) {
    throw 'BAT UTF-8 dekódolása sikertelen'
}
if ($batText -match '(?<!\r)\n') {
    throw 'BAT contains LF-only line endings instead of CRLF'
}
if ($batText -notmatch 'set /p "USER_DIR=Telepitesi mappa: ') {
    throw 'Missing interactive install path prompt'
}

function Invoke-Installer([string]$target) {
    $command = 'call telepites.bat "{0}"' -f $target
    & $env:ComSpec /d /c $command
    if ($LASTEXITCODE -ne 0) {
        throw "Installer failed: $LASTEXITCODE ($target)"
    }
}

if (Test-Path -LiteralPath $destDir) {
    Remove-Item -LiteralPath $destDir -Recurse -Force
}

# First install, creating the destination directory.
Invoke-Installer $destDir
if (-not (Test-Path -LiteralPath $destExe -PathType Leaf)) {
    throw 'The selected destination did not receive the executable.'
}
$expected = (Get-FileHash -LiteralPath $sourceExe -Algorithm SHA256).Hash
$actual = (Get-FileHash -LiteralPath $destExe -Algorithm SHA256).Hash
if ($expected -ne $actual) {
    throw 'EXE differs after installation.'
}

# Second install to same destination must back up the previous executable.
Invoke-Installer $destDir
$backups = @(Get-ChildItem -LiteralPath $destDir -File -Filter 'name - number copy.exe.backup_*')
if ($backups.Count -lt 1) {
    throw 'The prior version was not backed up.'
}
$backupHash = (Get-FileHash -LiteralPath $backups[0].FullName -Algorithm SHA256).Hash
if ($backupHash -ne $expected) {
    throw 'The backup does not match the prior installed EXE.'
}

# Copy the BAT into the destination and verify same-source/target is harmless.
Copy-Item -LiteralPath $batPath -Destination (Join-Path $destDir 'telepites.bat')
Push-Location $destDir
try {
    Invoke-Installer $destDir
}
finally {
    Pop-Location
}

Write-Host 'Windows installer integration tests passed (custom path, UTF-8+CRLF, backup, same-path).'