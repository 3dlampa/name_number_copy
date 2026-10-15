$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
& (Join-Path $root 'tests/test_installer_elevation.ps1')
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
foreach ($f in @('setup_browser.ps1', 'start_opencart_browser.ps1', 'elevate_installer.ps1','installer_common.ps1','uninstall.ps1')) {
    $b = [IO.File]::ReadAllBytes((Join-Path $root $f))
    if ($b.Length -lt 100 -or $b[0] -ne 239 -or $b[1] -ne 187 -or $b[2] -ne 191) { throw "PowerShell 5.1 UTF8 BOM missing: $f" }
}

$env:NNC_TEST_SKIP_LAUNCH = '1'
$env:NNC_TEST_ROOT = $testUser
$env:NNC_TEST_BRAVE_PATH = $fakeBrave
$env:NNC_TEST_CHROME_PATH = $fakeChrome
$env:NNC_TEST_EDGE_PATH = $fakeEdge
try {
    if (-not ([IO.Path]::GetFullPath($destDir)).StartsWith(([IO.Path]::GetFullPath($env:RUNNER_TEMP)).TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe test cleanup' }
    if (Test-Path -LiteralPath $destDir) { Remove-Item -LiteralPath $destDir -Recurse -Force }
    function Invoke-Installer([string]$target) {
        $command = 'call telepites.bat "{0}" /autostart:on' -f $target
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
    # Fake browser executables legitimately live under RUNNER_TEMP, possibly Users/AppData.
    # Assert the actual data contract rather than forbidding those strings in EXE paths.
    foreach ($setting in $config.Browsers.PSObject.Properties) {
        $fields = @($setting.Value.PSObject.Properties.Name)
        if ($fields.Count -ne 2 -or $fields -notcontains 'Exe' -or $fields -notcontains 'Port') { throw 'Machine config contains user profile/session data' }
    }
    if ($config.Browsers.Brave.Exe -ne $fakeBrave -or $config.Browsers.Chrome.Exe -ne $fakeChrome -or $config.Browsers.Edge.Exe -ne $fakeEdge) { throw 'Wrong browser paths' }
    if (-not (Test-Path -LiteralPath (Join-Path $testUser 'CommonStartup\OpenCart Rendelesmasolo - bongeszoinditas.lnk'))) { throw 'Windows-login autostart missing' }
    foreach ($name in @('Brave','Chrome','Edge')) {
        foreach ($location in @('PublicDesktop','CommonPrograms\OpenCart Rendelesmasolo')) {
            $lnk = Join-Path $testUser "$location\OpenCart - $name.lnk"
            if (-not (Test-Path -LiteralPath $lnk)) { throw "Browser shortcut missing: $lnk" }
            $target = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
            if ($target.TargetPath -ne $exeTarget -or $target.Arguments -ne ('--start-browser ' + $name)) { throw "Browser shortcut target incorrect: $lnk" }
        }
    }

    # Szuz Windows 11: Brave/Chrome nelkul is Edge + 9222.
    $edgeOnlyUser = Join-Path $runnerRoot 'EdgeOnlyMachine'
    & (Join-Path $destDir 'setup_browser.ps1') -InstallDir $destDir -TestRoot $edgeOnlyUser -EdgePath $fakeEdge -SkipLaunch -AutoStart On
    $edgeCfg = Get-Content -LiteralPath (Join-Path $destDir 'opencart_browser_config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($edgeCfg.Primary -ne 'Edge' -or $edgeCfg.Browsers.Edge.Port -ne 9222) { throw 'Edge-only fresh Windows setup failed' }
    if (-not (Test-Path -LiteralPath (Join-Path $edgeOnlyUser 'CommonStartup\OpenCart Rendelesmasolo - bongeszoinditas.lnk'))) { throw 'Edge-only machine startup shortcut missing' }
    if (Test-Path -LiteralPath (Join-Path $edgeOnlyUser 'Profiles')) { throw 'Setup prematurely created an admin-bound profile' }

    # Visszaallitjuk a teszt teljes ketbongeszos konfiguraciojat, a masodik telepites ezt frissiti.
    # Reinstall must remove only this installer's legacy backups and create none.
    $legacyFiles = @(
        (Join-Path $destDir 'name - number copy.exe.backup_20261012_110113_288'),
        (Join-Path $destDir 'opencart_browser_config.json.backup_20261012_110113_288'),
        (Join-Path $destDir 'setup_browser.ps1.backup_4761_23297'),
        (Join-Path $destDir 'start_opencart_browser.ps1.backup_8058_15277'),
        (Join-Path $destDir 'elevate_installer.ps1.backup_123_456'),
        (Join-Path $testUser 'CommonStartup\OpenCart Rendelesmasolo - bongeszoinditas.lnk.backup_20261012_110113_288')
    )
    foreach ($name in @('Brave','Chrome','Edge')) {
        foreach ($location in @('PublicDesktop','CommonPrograms\OpenCart Rendelesmasolo')) {
            $legacyFiles += Join-Path $testUser "$location\OpenCart - $name.lnk.backup_20261012_110113_288"
        }
    }
    foreach ($file in $legacyFiles) { [IO.File]::WriteAllText($file, 'legacy installer backup') }
    $unrelated = Join-Path $testUser 'CommonStartup\OtherApp.lnk.backup_20261012_110113_288'
    [IO.File]::WriteAllText($unrelated, 'unrelated backup')
    $unrecognized = Join-Path $destDir 'name - number copy.exe.backup_notes'
    [IO.File]::WriteAllText($unrecognized, 'not an installer-generated suffix')
    Invoke-Installer $destDir
    function Assert-NoInstallerBackups {
        foreach ($file in $legacyFiles) {
            if (Test-Path -LiteralPath $file) { throw "Legacy installer backup remains: $file" }
        }
        $scanDirs = @($destDir, (Join-Path $testUser 'CommonStartup'), (Join-Path $testUser 'PublicDesktop'), (Join-Path $testUser 'CommonPrograms\OpenCart Rendelesmasolo'))
        foreach ($dir in $scanDirs) {
            $remaining = @(Get-ChildItem -LiteralPath $dir -File -Filter '*.backup_*' | Where-Object { $_.FullName -ne $unrelated -and $_.FullName -ne $unrecognized })
            if ($remaining.Count -gt 0) { throw "Reinstall created backups: $($remaining.FullName -join ', ')" }
        }
        if ([IO.File]::ReadAllText($unrelated) -ne 'unrelated backup' -or
            [IO.File]::ReadAllText($unrecognized) -ne 'not an installer-generated suffix') { throw 'Unrelated file changed during cleanup' }
        if ((Get-FileHash -LiteralPath $exeTarget -Algorithm SHA256).Hash -ne $expected) { throw 'Reinstalled EXE differs' }
    }
    Assert-NoInstallerBackups
    $configAfterReinstall = Get-Content -LiteralPath (Join-Path $destDir 'opencart_browser_config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($configAfterReinstall.Scope -ne 'Machine') { throw 'Reinstall changed machine-wide scope' }

    # Same-source-destination directory should still reconfigure browsers safely.
    foreach ($f in @('telepites.bat','elevate_installer.ps1','setup_browser.ps1','start_opencart_browser.ps1','installer_common.ps1','uninstall.ps1','eltavolitas.bat','HASZNALATI_FELTETELEK.txt','VERSION')) {
        Copy-Item -LiteralPath (Join-Path $root $f) -Destination (Join-Path $destDir $f) -Force
    }
    Push-Location $destDir
    try { Invoke-Installer $destDir } finally { Pop-Location }
    Assert-NoInstallerBackups
    foreach ($name in @('Brave','Chrome','Edge')) {
        foreach ($location in @('PublicDesktop','CommonPrograms\OpenCart Rendelesmasolo')) {
            $lnk = Join-Path $testUser "$location\OpenCart - $name.lnk"
            $link = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
            if ($link.TargetPath -ne $exeTarget -or $link.Arguments -ne ('--start-browser ' + $name)) { throw "Reinstall broke launcher: $lnk" }
        }
    }
    $autostart = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $testUser 'CommonStartup\OpenCart Rendelesmasolo - bongeszoinditas.lnk'))
    if ($autostart.TargetPath -ne $exeTarget -or $autostart.Arguments -ne '--start-browser Auto --autostart') { throw 'Reinstall broke autostart' }

    # An install on a PC with no supported browser must stop instead of claiming success.
    $missingDest = Join-Path $runnerRoot 'NoBrowsers'
    $missingUser = Join-Path $runnerRoot 'MissingUser'
    $didFail = $false
    try {
        & (Join-Path $destDir 'setup_browser.ps1') -InstallDir $destDir -TestRoot $missingUser -ForceNoBrowsers -SkipLaunch
    } catch { $didFail = $true }
    if (-not $didFail) { throw 'No-browser setup did not fail' }
    if (Test-Path -LiteralPath $missingUser) { throw 'No-browser path was mutated' }

    # Regression: a gepi ikonok letrehozasa ONMAGABAN soha nem sikeres CDP.
    $installerCode = Get-Content -LiteralPath $batPath -Raw -Encoding UTF8
    if ($installerCode -notmatch 'goto :VERIFY_BROWSER' -or
        $installerCode -notmatch ':MACHINE_STAGE_SUCCESS' -or
        $installerCode -notmatch 'name - number copy.exe.*--start-browser Auto') {
        throw 'Installer does not verify a real current-user CDP connection after UAC'
    }

    $starter = Join-Path $destDir 'start_opencart_browser.ps1'
    $fakeProfile = Join-Path $runnerRoot 'FakeLoggedInUser'
    New-Item -ItemType Directory -Force -Path $fakeProfile | Out-Null
    # An explicit test-user root permits a fixture-only port, leaving host browsers intact.
    $probe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
    $probe.Start(); $testPort=$probe.LocalEndpoint.Port; $probe.Stop()
    # This fixture checks the transport only; normal Brave additionally requires
    # its existing data directory and launch identity (covered by the native test).
    $testBrowser = 'Edge'
    $configPath = Join-Path $destDir 'opencart_browser_config.json'
    $transportConfig = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $transportConfig.Browsers.Edge.Port = $testPort
    [IO.File]::WriteAllText($configPath,($transportConfig | ConvertTo-Json -Depth 5),(New-Object Text.UTF8Encoding($false)))
    # No browser port: check-only must FAIL, not report a false installation success.
    & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $starter -Browser $testBrowser -CheckOnly -TestUserRoot $fakeProfile *> $null
    if ($LASTEXITCODE -eq 0) { throw 'Browser launcher accepted a missing CDP endpoint' }

    # Mock CDP endpoint returns /json/version and /json/list, testing the SAME
    # conditions that the installer verifies after normal-user startup.
    $server = Start-Job -ScriptBlock {
        param([int]$testPort)
        $tcp = [System.Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $testPort)
        $tcp.Start()
        try {
            # A ket CDP kerest kiszolgaljuk, utana a tesztszerver MAGATOL kilep.
            # Ne tartsunk nyitva vegtelen blokkolt AcceptTcpClient folyamatot.
            for ($requestIndex=0; $requestIndex -lt 4; $requestIndex++) {
                $client = $tcp.AcceptTcpClient()
                try {
                    $client.ReceiveTimeout = 5000
                    $stream = $client.GetStream()
                    $data = New-Object byte[] 8192
                    $count = $stream.Read($data,0,$data.Length)
                    $req = [Text.Encoding]::ASCII.GetString($data,0,$count)
                    $body = if ($req -match '/json/version') {
                        '{"Browser":"Chromium/test","webSocketDebuggerUrl":"ws://127.0.0.1:' + $testPort + '/devtools/browser/1"}'
                    } else { '[]' }
                    $payload = [Text.Encoding]::UTF8.GetBytes($body)
                    $CRLF = [string][char]13 + [char]10
                    $head = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK" + $CRLF + "Content-Type: application/json" + $CRLF + "Content-Length: $($payload.Length)" + $CRLF + "Connection: close" + $CRLF + $CRLF)
                    $stream.Write($head,0,$head.Length)
                    $stream.Write($payload,0,$payload.Length)
                    $stream.Flush()
                } finally {
                    $client.Close()
                }
            }
        } finally { $tcp.Stop() }
    } -ArgumentList $testPort
    try {
        Start-Sleep -Seconds 2
        & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $starter -Browser $testBrowser -CheckOnly -TestUserRoot $fakeProfile
        if ($LASTEXITCODE -ne 0) { throw 'CDP live-port verification rejected a valid port' }
        & $exeTarget --start-browser $testBrowser --check-only --test-user-root $fakeProfile
        if ($LASTEXITCODE -ne 0) { throw 'Native EXE launcher rejected healthy CDP' }
    } finally {
        Stop-Job $server -ErrorAction SilentlyContinue
        Remove-Job $server -Force -ErrorAction SilentlyContinue
    }
    Write-Host 'PASS: missing-CDP error + mock healthy-CDP success; current-user launcher path verified.'
    # Regression: ha a BAT mar emelt jogosultsaggal fut, nem eleg a
    # -CheckOnly. A normal user browserjet interaktiv, Limited jogu
    # Windows Task Scheduler feladatnak kell elinditania.
    $batCurrent = [IO.File]::ReadAllText($batPath)
    $starterCurrent = [IO.File]::ReadAllText($starter)
    $adminBranch = [regex]::Match($batCurrent,'(?s)\r\n:VERIFY_ADMIN\r\n(.*?)\r\n:COPY_SCRIPT\r\n')
    if (-not $adminBranch.Success) { throw 'Missing explicit elevated-installer branch' }
    if ($adminBranch.Groups[1].Value -notmatch '-FromElevatedInstaller' -or
        $adminBranch.Groups[1].Value -match '-CheckOnly') {
        throw 'Elevated installer still skips live CDP startup'
    }
    if ($starterCurrent -notmatch 'TASK_LOGON_INTERACTIVE_TOKEN' -and
        $starterCurrent -notmatch 'InteractiveToken') {
        throw 'Missing interactive logged-on user launch'
    }
    if ($starterCurrent -notmatch 'RunLevel = 0' -or
        $starterCurrent -notmatch 'RegisterTaskDefinition' -or
        $starterCurrent -notmatch 'DeleteTask') {
        throw 'Scheduled task must have limited privileges and be removed after use'
    }
    Write-Host 'PASS: elevated installer uses temporary Limited/InteractiveToken task, not CheckOnly.'


    & (Join-Path $root 'tests/test_native_browser_windows.ps1')
    & (Join-Path $root 'tests/test_installer_consent_uninstall.ps1')
    & (Join-Path $root 'tests/test_uninstall_bat_windows.ps1')
    Write-Host 'PASS: all-user shortcuts/startup, Brave/Chrome/Edge, Edge-only Win11, per-user profile, no new backups, legacy cleanup, unrelated files retained, hash, no-browser STOP, same-path, Unicode, CRLF.'
} finally {
    Remove-Item Env:NNC_TEST_SKIP_LAUNCH -ErrorAction SilentlyContinue
    Remove-Item Env:NNC_TEST_ROOT -ErrorAction SilentlyContinue
    Remove-Item Env:NNC_TEST_BRAVE_PATH -ErrorAction SilentlyContinue
    Remove-Item Env:NNC_TEST_CHROME_PATH -ErrorAction SilentlyContinue
    Remove-Item Env:NNC_TEST_EDGE_PATH -ErrorAction SilentlyContinue
}
