#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'This real-browser test runs only on a disposable GitHub Actions worker, never a personal profile.' }
$root = (Get-Location).Path
$normal = Join-Path $env:LOCALAPPDATA 'BraveSoftware\Brave-Browser\User Data'
if (Test-Path -LiteralPath $normal) { throw 'A normal Brave profile already exists; refusing to touch it.' }
$stage = Join-Path $env:RUNNER_TEMP ('nnc-real-brave-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage -Force | Out-Null
# Official stable vendor ZIP, discovered and digest-verified during this change.
$url = 'https://github.com/brave/brave-browser/releases/download/v1.97.57/brave-v1.97.57-win32-x64.zip'
$archive = Join-Path $stage 'brave.zip'
Invoke-WebRequest -Uri $url -OutFile $archive
if ((Get-FileHash -LiteralPath $archive).Hash.ToLowerInvariant() -ne 'c986dc568bbabf7dc5dcce0bb354597eaafeab6dc47412d37ff7458d8b5d0550') { throw 'Vendor Brave archive SHA256 mismatch.' }
Expand-Archive -LiteralPath $archive -DestinationPath (Join-Path $stage 'vendor')
$binaries = @(Get-ChildItem -LiteralPath (Join-Path $stage 'vendor') -Filter 'brave.exe' -File -Recurse)
if ($binaries.Count -ne 1) { throw 'Expected exactly one vendor Brave executable.' }
$brave = $binaries[0].FullName
$signature = Get-AuthenticodeSignature -LiteralPath $brave
if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Brave') { throw 'Brave vendor signature is not valid.' }
$exe = Join-Path $stage 'name - number copy.exe'
Copy-Item -LiteralPath (Join-Path $root 'name - number copy.exe') -Destination $exe
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
$listener.Start(); $port=$listener.LocalEndpoint.Port; $listener.Stop()
$config = @{ Primary='Brave'; BraveProfileMode='Existing'; Browsers=@{Brave=@{Exe=$brave;Port=$port}} }
[IO.File]::WriteAllText((Join-Path $stage 'opencart_browser_config.json'),($config | ConvertTo-Json -Depth 5),(New-Object Text.UTF8Encoding($false)))
New-Item -ItemType Directory -Path $normal -Force | Out-Null
$sentinel = Join-Path $normal 'nnc-existing-profile-test.txt'
[IO.File]::WriteAllText($sentinel,'PRESERVE ORIGINAL PROFILE')
function Invoke-RealBrave {
    $p=Start-Process -FilePath $exe -ArgumentList @('--start-browser','Brave','--test-user-root',('"'+$env:LOCALAPPDATA+'"')) -WindowStyle Hidden -PassThru
    if (-not $p.WaitForExit(30000)) { throw 'Real Brave launcher did not return after startup.' }
    if ($p.ExitCode -ne 0) {
        Get-Content -LiteralPath (Join-Path $env:TEMP 'name_number_copy_browser.log') -Tail 12
        throw "Real Brave normal-profile launch failed: $($p.ExitCode)"
    }
}
function Close-TestBrave {
    $record = Get-Content -LiteralPath (Join-Path $env:LOCALAPPDATA 'NameNumberCopy\BrowserProfiles\brave-launch.json') -Raw | ConvertFrom-Json
    if ([IO.Path]::GetFullPath([string]$record.Profile) -ne [IO.Path]::GetFullPath($normal)) { throw 'Unexpected profile; refusing browser close.' }
    $process = [Diagnostics.Process]::GetProcessById([int]$record.Identity.PID)
    if ($process.MainModule.FileName -ne $brave) { throw 'Unexpected process; refusing browser close.' }
    $version = Invoke-RestMethod -Uri "http://127.0.0.1:$port/json/version" -TimeoutSec 3
    $socket = New-Object Net.WebSockets.ClientWebSocket
    $timeout = New-Object Threading.CancellationTokenSource
    $timeout.CancelAfter(5000)
    try {
        $socket.ConnectAsync([Uri]$version.webSocketDebuggerUrl,$timeout.Token).GetAwaiter().GetResult()
        $bytes=[Text.Encoding]::UTF8.GetBytes('{"id":1,"method":"Browser.close"}')
        $socket.SendAsync([ArraySegment[byte]]::new($bytes),[Net.WebSockets.WebSocketMessageType]::Text,$true,$timeout.Token).GetAwaiter().GetResult()
    } finally { $socket.Dispose(); $timeout.Dispose() }
    if (-not $process.WaitForExit(10000)) { throw 'Disposable test Brave did not close gracefully.' }
}
$opened=$false
try {
    Invoke-RealBrave; $opened=$true
    if (-not (Test-Path -LiteralPath (Join-Path $normal 'Local State'))) { throw 'Real Brave did not use its normal data directory.' }
    Invoke-RealBrave # Same live process must be reused, with its validated profile/owner.
    Close-TestBrave; $opened=$false
    Invoke-RealBrave; $opened=$true
    if ([IO.File]::ReadAllText($sentinel) -ne 'PRESERVE ORIGINAL PROFILE') { throw 'Real browser changed existing profile marker.' }
    Write-Host 'PASS: official signed Brave v1.97.57; actual default data directory, native startup, live reuse and graceful close/restart; existing profile data retained.'
} finally {
    if ($opened) { Close-TestBrave }
}
