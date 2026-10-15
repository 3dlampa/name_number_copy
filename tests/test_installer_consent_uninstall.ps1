$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
. (Join-Path $root 'tests/installer_test_helpers.ps1')
$stage = Join-Path $env:RUNNER_TEMP ('nnc-consent-' + [guid]::NewGuid().ToString('N'))
$destination = Join-Path $stage 'sajat mappa é ! & (teszt)'
$machine = Join-Path $stage 'machine'
$profile = Join-Path $stage 'user\NameNumberCopy\BrowserProfiles\Chrome'
New-Item -ItemType Directory -Path $stage -Force | Out-Null
function Invoke-ConsentInstaller([string]$AutoAnswer, [string]$Approve, [int]$Expected, [string]$BraveAnswer = 'I') {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $env:ComSpec
    $info.Arguments = '/d /v:off /s /c ""%NNC_CONSENT_INSTALLER%""'
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.StandardInputEncoding = New-Object Text.UTF8Encoding($false)
    $info.EnvironmentVariables['NNC_CONSENT_INSTALLER'] = Join-Path $root 'telepites.bat'
    $info.EnvironmentVariables['NNC_TEST_SKIP_LAUNCH'] = '1'
    $info.EnvironmentVariables['NNC_TEST_ROOT'] = $machine
    $process = [Diagnostics.Process]::Start($info)
    $promptText = Read-InstallerPrompt $process 'Telepitesi mappa: '
    $process.StandardInput.WriteLine($destination)
    $promptText += Read-InstallerPrompt $process '(I/N, Enter=N): '
    $process.StandardInput.WriteLine($AutoAnswer)
    $promptText += Read-InstallerPrompt $process '(I/N, Enter=I): '
    $process.StandardInput.WriteLine($BraveAnswer)
    $promptText += Read-InstallerPrompt $process '(I/N): '
    $process.StandardInput.WriteLine($Approve)
    $process.StandardInput.Close()
    $stdout = $promptText + $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    try {
        if ($process.ExitCode -ne $Expected) { throw "Consent result $($process.ExitCode): $stdout $stderr" }
    } finally { $process.Dispose() }
}
Invoke-ConsentInstaller 'I' 'N' 1
if (Test-Path -LiteralPath $destination) { throw 'Cancellation changed destination' }
if (Test-Path -LiteralPath $machine) { throw 'Cancellation changed shortcuts' }
Invoke-ConsentInstaller 'N' 'I' 0
$startup = Join-Path $machine 'CommonStartup\OpenCart Rendelesmasolo - bongeszoinditas.lnk'
if (Test-Path -LiteralPath $startup) { throw 'Autostart installed without consent' }
$config = Get-Content -LiteralPath (Join-Path $destination 'opencart_browser_config.json') -Raw | ConvertFrom-Json
if ($config.BraveProfileMode -ne 'Existing') { throw 'Existing Brave profile choice lost' }
Invoke-ConsentInstaller 'N' 'I' 0 'N'
$config = Get-Content -LiteralPath (Join-Path $destination 'opencart_browser_config.json') -Raw | ConvertFrom-Json
if ($config.BraveProfileMode -ne 'Isolated') { throw 'Separate Brave profile choice lost' }
Invoke-ConsentInstaller 'I' 'I' 0
if (-not (Test-Path -LiteralPath $startup)) { throw 'Approved autostart missing' }
Invoke-ConsentInstaller 'N' 'I' 0
if (Test-Path -LiteralPath $startup) { throw 'Opt-out failed to remove old owned autostart' }

$exe = Join-Path $destination 'name - number copy.exe'
$hash = (Get-FileHash -LiteralPath $exe).Hash
$manifestPath = Join-Path $destination 'installation_manifest.json'
$goodManifest = [IO.File]::ReadAllText($manifestPath)
[IO.File]::WriteAllText($manifestPath, '{"Product":"OtherProduct","InstallDir":"C:\\"}')
$failed = $false
try { & (Join-Path $destination 'uninstall.ps1') -InstallDir $destination -TestRoot $machine } catch { $failed = $true }
if (-not $failed -or (Get-FileHash -LiteralPath $exe).Hash -ne $hash) { throw 'Foreign manifest accepted or removed files' }
[IO.File]::WriteAllText($manifestPath, $goodManifest)

New-Item -ItemType Directory -Path $profile -Force | Out-Null
$personal = Join-Path $profile 'personal-data.txt'
$unrelated = Join-Path $destination 'unrelated.txt'
[IO.File]::WriteAllText($personal, 'keep logins')
[IO.File]::WriteAllText($unrelated, 'keep unrelated')
$foreignLink = Join-Path $machine 'PublicDesktop\OpenCart - Edge.lnk'
$link = (New-Object -ComObject WScript.Shell).CreateShortcut($foreignLink)
$link.TargetPath = $env:ComSpec
$link.Save()
& (Join-Path $destination 'uninstall.ps1') -InstallDir $destination -TestRoot $machine
if (Test-Path -LiteralPath $exe) { throw 'Uninstall left EXE' }
if (Test-Path -LiteralPath $manifestPath) { throw 'Uninstall left manifest' }
if (Test-Path -LiteralPath $startup) { throw 'Uninstall left startup' }
if (-not (Test-Path -LiteralPath $foreignLink)) { throw 'Uninstall removed unrelated shortcut' }
if ([IO.File]::ReadAllText($personal) -ne 'keep logins' -or [IO.File]::ReadAllText($unrelated) -ne 'keep unrelated') { throw 'Uninstall changed unrelated files/profile' }
$ownLinks = @(Get-ChildItem -LiteralPath (Join-Path $machine 'PublicDesktop') -Filter '*.lnk' |
    Where-Object FullName -NE $foreignLink)
if ($ownLinks.Count -ne 0) { throw 'Uninstall left owned desktop shortcuts' }
Write-Host 'PASS: cancellation before writes; explicit autostart On/Off; opt-out update; foreign manifest rejected; targeted uninstall preserves unrelated shortcuts/files and browser profiles.'
