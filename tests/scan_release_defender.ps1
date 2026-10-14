#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ArtifactDir,
      [Parameter(Mandatory=$true)][string]$ZipName,
      [Parameter(Mandatory=$true)][string]$OutputDir)
$ErrorActionPreference = 'Stop'
$status = Get-MpComputerStatus
if (-not $status.AntivirusEnabled -or $status.AMRunningMode -ne 'Normal') { throw 'A Defender nem aktiv normal modban; nincs ervenyes vizsgalat.' }
$platform = Join-Path $env:ProgramData 'Microsoft\Windows Defender\Platform'
$directory = Get-ChildItem -LiteralPath $platform -Directory | Where-Object { $_.Name -match '^\d+\.' } |
    Sort-Object Name -Descending | Select-Object -First 1
$scanner = Join-Path $directory.FullName 'MpCmdRun.exe'
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
$results = @()
foreach ($name in @('name - number copy.exe',$ZipName)) {
    if ([IO.Path]::GetFileName($name) -ne $name) { throw 'A fajlnev nem tartalmazhat utvonalat.' }
    $path = (Resolve-Path -LiteralPath (Join-Path $ArtifactDir $name)).Path
    $before = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    $log = Join-Path $OutputDir ($name + '.defender.log')
    & $scanner -Scan -ScanType 3 -File $path -DisableRemediation *> $log
    $code = $LASTEXITCODE
    $after = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    $text = [IO.File]::ReadAllText($log)
    if ($before -ne $after) { throw "A fajl megvaltozott a vizsgalat kozben: $name" }
    if ($code -ne 0 -or $text -notmatch 'found no threats') { throw "A vizsgalat nem adott tiszta eredmenyt: $name / $code. Naplo: $log" }
    $results += @{ File=$name; SHA256=$after; ExitCode=$code; Result='found no threats' }
}
$report = @{ Timestamp=(Get-Date).ToString('o'); Scanner='Microsoft Defender';
    Platform=$status.AMProductVersion; Engine=$status.AMEngineVersion; Signature=$status.AntivirusSignatureVersion;
    SignatureAge=$status.AntivirusSignatureAge; Files=$results; DisableRemediation=$true }
[IO.File]::WriteAllText((Join-Path $OutputDir 'defender-result.json'),($report | ConvertTo-Json -Depth 6),(New-Object Text.UTF8Encoding($false)))
$report | ConvertTo-Json -Depth 6
