$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$batPath = Join-Path $root 'telepites.bat'
$exeSource = Join-Path $root 'name - number copy.exe'
$runnerRoot = Join-Path $env:RUNNER_TEMP 'name number copy teszt - ékezet és spaces'
$destDir = Join-Path $runnerRoot 'Photoshop és Illustrator scriptek'
$exeTarget = Join-Path $destDir 'name - number copy.exe'
$testUser = Join-Path $runnerRoot 'FakeUser'
$fakeDir = Join-Path $runnerRoot 'FakeBrowsers'
New-Item -ItemType Directory -Path $fakeDir -Force | Out-Null
$fakeBrave = Join-Path $fakeDir 'brave.exe'
$fakeChrome = Join-Path $fakeDir 'chrome.exe'
$fakeEdge = Join-Path $fakeDir 'msedge.exe'
Copy-Item -LiteralPath "$env:WINDIR\System32\cmd.exe" -Destination $fakeBrave -Force
Copy-Item -LiteralPath "$env:WINDIR\System32\cmd.exe" -Destination $fakeChrome -Force
Copy-Item -LiteralPath "$env:WINDIR\System32\cmd.exe" -Destination $fakeEdge -Force

$bytes = [IO.File]::ReadAllBytes($batPath)
$text = [Text.Encoding]::UTF8.GetString($bytes)
if ($text -match '(?<!\r)\n') { throw 'Telepito BAT nem CRLF' }
if ($text -notmatch 'Telepitesi mappa: ') { throw 'Telepitesi mappa kerdes hianyzik' }
foreach ($f in @('setup_browser.ps1', 'start_opencart_browser.ps1')) {
    $b = [IO.File]::ReadAllBytes((Join-Path $root $f))
    if ($b.Length -lt 1000 -or $b[0] -ne 239 -or $b[1] -ne 187 -or $b[2] -ne 191) { throw "PowerShell 5.1 UTF8 BOM missing: $f" }
}

$env:NNC_TEST_SKIP_LAUNCH = '1'
$env:NNC_TEST_ROOT = $testUser
$env:NNC_TEST_BRAVE_PATH = $fakeBrave
$env:NNC_TEST_CHROME_PATH = $fakeChrome
$env:NNC_TEST_EDGE_PATH = $fakeEdge
try {
    if (Test-Path -LiteralPath $destDir) { Remove-Item -LiteralPath $destDir -Recurse -Force }
    function Invoke-Installer([string]$target) {
        $command = 'call telepites.bat "{0}"' -f $target
        & $env:ComSpec /d /c $command
        if ($LASTEXITCODE -ne 0) { throw "Installer failed: $LASTEXITCODE, target=$target" }
    }
    Invoke-Installer $destDir
    if (-not (Test-Path -LiteralPath $exeTarget -PathType Leaf)) { throw 'Target EXE missing' }
    $expected = (Get-FileHash -LiteralPath $exeSource -Algorithm SHA256).Hash
    $actual = (Get-FileHash -LiteralPath $exeTarget -Algorithm SHA256).Hash
    if ($expected -ne $actual) { throw 'Target EXE SHA differs' }

    $config = (Get-Content -LiteralPath (Join-Path $destDir 'opencart_browser_config.json') -Raw -Encoding UTF8) | ConvertFrom-Json
    if ($config.Browsers.Brave.Port -ne 9222 -or $config.Browsers.Chrome.Port -ne 9223 -or $config.Browsers.Edge.Port -ne 9222) { throw 'Wrong CDP ports' }
    if ($config.Scope -ne 'Machine') { throw 'Config is not machine-scoped' }
    if ($config.Browsers.Brave.PSObject.Properties.Name -contains 'Profile') { throw 'Admin-account profile wrongly saved in machine config' }
    $configText = Get-Content -LiteralPath (Join-Path $destDir 'opencart_browser_config.json') -Raw -Encoding UTF8
    if ($configText -match 'FakeUser|Users\\|\\AppData\\') { throw 'Machine config contains a user-specific directory' }
    if ($config.Browsers.Brave.Exe -ne $fakeBrave -or $config.Browsers.Chrome.Exe -ne $fakeChrome -or $config.Browsers.Edge.Exe -ne $fakeEdge) { throw 'Wrong browser paths' }
    if (-not (Test-Path -LiteralPath (Join-Path $testUser 'CommonStartup\OpenCart Rendelesmasolo - bongeszoinditas.lnk'))) { throw 'Windows-login autostart missing' }
    foreach ($name in @('Brave','Chrome','Edge')) {
        foreach ($location in @('PublicDesktop','CommonPrograms\OpenCart Rendelesmasolo')) {
            $lnk = Join-Path $testUser "$location\OpenCart - $name.lnk"
            if (-not (Test-Path -LiteralPath $lnk)) { throw "Browser shortcut missing: $lnk" }
            $target = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
            if ($target.Arguments -notmatch [regex]::Escape('start_opencart_browser.ps1')) { throw "Browser shortcut target incorrect: $lnk" }
        }
    }

    # Szuz Windows 11: Brave/Chrome nelkul is Edge + 9222.
    $edgeOnlyUser = Join-Path $runnerRoot 'EdgeOnlyMachine'
    & (Join-Path $destDir 'setup_browser.ps1') -InstallDir $destDir -TestRoot $edgeOnlyUser -EdgePath $fakeEdge -SkipLaunch
    $edgeCfg = Get-Content -LiteralPath (Join-Path $destDir 'opencart_browser_config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($edgeCfg.Primary -ne 'Edge' -or $edgeCfg.Browsers.Edge.Port -ne 9222) { throw 'Edge-only fresh Windows setup failed' }
    if (-not (Test-Path -LiteralPath (Join-Path $edgeOnlyUser 'CommonStartup\OpenCart Rendelesmasolo - bongeszoinditas.lnk'))) { throw 'Edge-only machine startup shortcut missing' }
    if (Test-Path -LiteralPath (Join-Path $edgeOnlyUser 'Profiles')) { throw 'Setup prematurely created an admin-bound profile' }

    # Visszaallitjuk a teszt teljes ketbongeszos konfiguraciojat, a masodik telepites ezt frissiti.
    # Two installs: existing EXE/config/shortcuts MUST be backed up.
    Invoke-Installer $destDir
    $backups = @(Get-ChildItem -LiteralPath $destDir -File -Filter 'name - number copy.exe.backup_*')
    if ($backups.Count -lt 1) { throw 'EXE backup missing on second install' }
    if ((Get-FileHash -LiteralPath $backups[0].FullName -Algorithm SHA256).Hash -ne $expected) { throw 'EXE backup SHA differs' }
    $configBackups = @(Get-ChildItem -LiteralPath $destDir -File -Filter 'opencart_browser_config.json.backup_*')
    if ($configBackups.Count -lt 1) { throw 'Config backup missing' }
    $configAfterReinstall = Get-Content -LiteralPath (Join-Path $destDir 'opencart_browser_config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($configAfterReinstall.Scope -ne 'Machine') { throw 'Reinstall changed machine-wide scope' }
    $shortcutBackups = @(Get-ChildItem -LiteralPath (Join-Path $testUser 'PublicDesktop') -File -Filter '*.lnk.backup_*')
    if ($shortcutBackups.Count -lt 2) { throw 'Shortcut backup missing' }

    # Same-source-destination directory should still reconfigure browsers safely.
    foreach ($f in @('telepites.bat','setup_browser.ps1','start_opencart_browser.ps1')) {
        Copy-Item -LiteralPath (Join-Path $root $f) -Destination (Join-Path $destDir $f) -Force
    }
    Push-Location $destDir
    try { Invoke-Installer $destDir } finally { Pop-Location }

    # An install on a PC with no supported browser must stop instead of claiming success.
    $missingDest = Join-Path $runnerRoot 'NoBrowsers'
    $missingUser = Join-Path $runnerRoot 'MissingUser'
    $didFail = $false
    try {
        & (Join-Path $destDir 'setup_browser.ps1') -InstallDir $destDir -TestRoot $missingUser -ForceNoBrowsers -SkipLaunch
    } catch { $didFail = $true }
    if (-not $didFail) { throw 'No-browser setup did not fail' }
    if (Test-Path -LiteralPath $missingUser) { throw 'No-browser path was mutated' }

    Write-Host 'PASS: all-user common shortcuts/startup, Brave/Chrome/Edge, Edge-only virgin Win11, per-user profile at runtime, backups, hash, no-browser STOP, same-path, Unicode, CRLF.'
} finally {
    Remove-Item Env:NNC_TEST_SKIP_LAUNCH -ErrorAction SilentlyContinue
    Remove-Item Env:NNC_TEST_ROOT -ErrorAction SilentlyContinue
    Remove-Item Env:NNC_TEST_BRAVE_PATH -ErrorAction SilentlyContinue
    Remove-Item Env:NNC_TEST_CHROME_PATH -ErrorAction SilentlyContinue
    Remove-Item Env:NNC_TEST_EDGE_PATH -ErrorAction SilentlyContinue
}