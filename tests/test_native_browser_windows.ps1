$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$stage = Join-Path $env:RUNNER_TEMP ('nnc-native-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage -Force | Out-Null
$exe = Join-Path $stage 'name - number copy.exe'
$fake = Join-Path $stage 'fake-browser.exe'
Copy-Item -LiteralPath (Join-Path $root 'name - number copy.exe') -Destination $exe
& go build -buildvcs=false -trimpath -ldflags '-H windowsgui -s -w' -o $fake ./tests/fake_browser
if ($LASTEXITCODE -ne 0) { throw 'Native browser fixture build failed' }
$busy = @([Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners() | ForEach-Object Port)
$port = if ($busy -notcontains 9222) { 9222 } elseif ($busy -notcontains 9223) { 9223 } else { throw 'No free test CDP port; leave live browsers intact.' }
$browser = if ($port -eq 9222) { 'Edge' } else { 'Chrome' }
$config = @{ Primary=$browser; Browsers=@{} }
$config.Browsers[$browser] = @{ Exe=$fake; Port=$port }
[IO.File]::WriteAllText((Join-Path $stage 'opencart_browser_config.json'),($config | ConvertTo-Json -Depth 5),(New-Object Text.UTF8Encoding($false)))
$userRoot = Join-Path $stage 'profil é ! & ( )'
$legacyName = if ($browser -eq 'Edge') { 'OpenCartEdgeDebug' } else { 'OpenCartChromeDebug' }
$profile = Join-Path $userRoot "$legacyName\User Data"
New-Item -ItemType Directory -Path $profile -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $profile 'existing-login.txt'),'keep existing login')
try {
    $process = Start-Process -FilePath $exe -ArgumentList @('--start-browser','Auto','--test-user-root',('"' + $userRoot + '"')) -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw 'Native browser launch did not prove healthy CDP' }
    $argv = Get-Content -LiteralPath (Join-Path $profile 'test-browser-argv.json') -Raw | ConvertFrom-Json
    foreach ($expected in @('--remote-debugging-address=127.0.0.1',"--remote-debugging-port=$port",('--user-data-dir=' + $profile),'--no-first-run')) {
        if ($argv -notcontains $expected) { throw "Windows native argv changed: $expected" }
    }
    if ([IO.File]::ReadAllText((Join-Path $profile 'existing-login.txt')) -ne 'keep existing login') { throw 'Native launcher changed existing login profile' }
    Write-Host 'PASS: actual native child process, literal Unicode/metacharacter profile argv, loopback-only CDP, Auto selection and legacy login-profile reuse.'
} finally {
    try { Invoke-WebRequest -Uri "http://127.0.0.1:$port/shutdown" -UseBasicParsing -TimeoutSec 2 | Out-Null } catch { }
}
