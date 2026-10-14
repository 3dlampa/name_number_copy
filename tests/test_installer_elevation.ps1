$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
. (Join-Path $root 'tests/installer_test_helpers.ps1')
$stage = Join-Path ([IO.Path]::GetTempPath()) ('nnc-elevation-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage | Out-Null
$utf8 = New-Object Text.UTF8Encoding($true)
$plainUtf8 = New-Object Text.UTF8Encoding($false)
# Substitute only the OS privilege gate and RunAs call; execute the real
# batch ingress, helper serialization, readable -File worker and CMD reentry.
$mock = @'
function Start-Process {
    param($FilePath, $ArgumentList, $Verb, $WindowStyle, [switch]$Wait, [switch]$PassThru, $ErrorAction)
    if ($Verb -ne 'RunAs' -or $WindowStyle -ne 'Normal' -or -not $Wait -or -not $PassThru) { throw 'Elevation contract changed' }
    $expected = Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe'
    if ($FilePath -ne $expected) { throw 'Elevation executable changed' }
    if ($ArgumentList -match '-EncodedCommand' -or $ArgumentList -notmatch '-File.*-Payload') { throw 'Readable elevation contract missing' }
    if ($env:NNC_CAPTURE_CANCEL -eq '1') { throw 'Simulated UAC cancellation' }
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $FilePath
    $info.Arguments = $ArgumentList
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.EnvironmentVariables['NNC_TEST_SKIP_LAUNCH'] = '1'
    $child = [Diagnostics.Process]::Start($info)
    try { $child.WaitForExit(); $code = $child.ExitCode } finally { $child.Dispose() }
    return [pscustomobject]@{ ExitCode = $code }
}
'@
$saved = @{}
$names = @('NNC_CASE_INSTALLER','NNC_CASE_DESTINATION','NNC_CAPTURE_OUTPUT','NNC_CAPTURE_EXIT','NNC_CAPTURE_CANCEL','NNC_TEST_SKIP_LAUNCH','NNC_LITERAL_CANARY','NNC_ELEVATE_INSTALLER','NNC_ELEVATE_DESTINATION','NNC_ELEVATE_CHILD')
foreach ($name in $names) { $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
try {
    $env:NNC_LITERAL_CANARY = 'SHOULD_NOT_EXPAND'
    $cases = @(
        @{ Name = 'normal'; Destination = 'C:\normal folder\cél'; Code = 0 },
        @{ Name = "pkg';Write-Output NNC_INJECTED;#"; Destination = "C:\dest';Write-Output NNC_INJECTED;#"; Code = 0 },
        @{ Name = "source';Write-Output NNC_INJECTED;#"; Destination = 'C:\ordinary'; Code = 0 },
        @{ Name = 'destination-only'; Destination = "C:\dest';Write-Output NNC_INJECTED;#"; Code = 0 },
        @{ Name = "unicode é ! & ^ ( ) %NNC_LITERAL_CANARY%"; Destination = "C:\é ! & ^ ( ) %NNC_LITERAL_CANARY%\end\"; Code = 0 },
        @{ Name = 'no-argument'; Destination = ''; Code = 0 },
        @{ Name = 'child-failure'; Destination = 'C:\ordinary'; Code = 7 },
        @{ Name = 'cancel'; Destination = 'C:\ordinary'; Code = 0; Cancel = $true }
    )
    foreach ($case in $cases) {
        $caseRoot = Join-Path $stage $case.Name
        New-Item -ItemType Directory -Path $caseRoot -Force | Out-Null
        $installer = Join-Path $caseRoot 'telepites.bat'
        $text = [IO.File]::ReadAllText((Join-Path $root 'telepites.bat'), [Text.Encoding]::UTF8)
        $end = $text.IndexOf([Environment]::NewLine + ':INSTALL_FILES' + [Environment]::NewLine)
        if ($end -ge 0) { $end += [Environment]::NewLine.Length }
        if ($end -lt 0) { throw 'Elevation boundary missing' }
        $prefix = $text.Substring(0, $end).Replace('fltmc >nul 2>&1', 'cmd.exe /d /c exit 1')
        $stub = @'
:INSTALL_FILES
set "NNC_CAPTURE_ARG=%INSTALL_DIR%"
set "NNC_CAPTURE_STAGE=%~2"
powershell.exe -NoProfile -Command "[IO.File]::WriteAllText($env:NNC_CAPTURE_OUTPUT, [string]$env:NNC_CAPTURE_ARG); if ($env:NNC_CAPTURE_STAGE -ne '/elevated-child') { exit 9 }"
endlocal & exit /b %NNC_CAPTURE_EXIT%
:VERIFY_BROWSER
endlocal & exit /b 0
:MISSING_SOURCE
:MISSING_SCRIPTS
:ELEVATION_FAIL
endlocal & exit /b 1
'@
        $stub = $stub.Replace([string][char]13, '').Replace([string][char]10, [Environment]::NewLine)
        [IO.File]::WriteAllText($installer, $prefix + $stub, $plainUtf8)
        $helper = [IO.File]::ReadAllText((Join-Path $root 'elevate_installer.ps1'), [Text.Encoding]::UTF8)
        [IO.File]::WriteAllText((Join-Path $caseRoot 'elevate_installer.ps1'), $helper.Replace("`$ErrorActionPreference = 'Stop'", ($mock + [Environment]::NewLine + "`$ErrorActionPreference = 'Stop'")), $utf8)
        foreach ($fixture in @('name - number copy.exe','setup_browser.ps1','start_opencart_browser.ps1','installer_common.ps1','uninstall.ps1','eltavolitas.bat','HASZNALATI_FELTETELEK.txt','VERSION')) {
            [IO.File]::WriteAllText((Join-Path $caseRoot $fixture), 'test fixture')
        }
        $env:NNC_CASE_INSTALLER = $installer
        $env:NNC_CASE_DESTINATION = $case.Destination
        $env:NNC_CAPTURE_OUTPUT = Join-Path $caseRoot 'received.txt'
        $env:NNC_CAPTURE_EXIT = [string]$case.Code
        $env:NNC_CAPTURE_CANCEL = if ($case.Cancel) { '1' } else { '0' }
        Remove-Item Env:NNC_TEST_SKIP_LAUNCH -ErrorAction SilentlyContinue
        $info = New-Object Diagnostics.ProcessStartInfo
        $info.FileName = Join-Path ([Environment]::SystemDirectory) 'cmd.exe'
        $info.Arguments = if ($case.Destination) { '/d /v:off /s /c ""%NNC_CASE_INSTALLER%" "%NNC_CASE_DESTINATION%""' } else { '/d /v:off /s /c ""%NNC_CASE_INSTALLER%""' }
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        $info.RedirectStandardInput = $true
        $info.RedirectStandardOutput = $true
        $info.RedirectStandardError = $true
        $child = [Diagnostics.Process]::Start($info)
        $promptText = ''
        if (-not $case.Destination) {
            $promptText += Read-InstallerPrompt $child 'Telepitesi mappa: '
            $child.StandardInput.WriteLine('C:\ordinary')
            $promptText += Read-InstallerPrompt $child '(I/N, Enter=N): '
            $child.StandardInput.WriteLine('N')
            $promptText += Read-InstallerPrompt $child '(I/N): '
            $child.StandardInput.WriteLine('I')
        }
        $child.StandardInput.Close()
        $stdout = $promptText + $child.StandardOutput.ReadToEnd()
        $stderr = $child.StandardError.ReadToEnd()
        $child.WaitForExit()
        $expectedCode = if ($case.Cancel -or $case.Code -ne 0) { 1 } else { 0 }
        if ($child.ExitCode -ne $expectedCode) { throw "Exit mismatch for $($case.Name): $($child.ExitCode) $stdout $stderr" }
        $child.Dispose()
        if ($stdout -match '(?m)^NNC_INJECTED\s*$') { throw 'Path executed as PowerShell source' }
        if ($case.Cancel) {
            if (Test-Path -LiteralPath $env:NNC_CAPTURE_OUTPUT) { throw 'Cancelled elevation launched child' }
        } else {
            $actual = [IO.File]::ReadAllText($env:NNC_CAPTURE_OUTPUT)
            $expectedPath = if ($case.Destination) { [IO.Path]::GetFullPath($case.Destination) } else { 'C:\ordinary' }
            if ($actual -cne $expectedPath) { throw "Path changed: [$actual] != [$expectedPath]" }
        }
    }
    # Illegal Windows path characters must fail before requesting elevation.
    $bad = Join-Path $stage 'invalid.ps1'
    [IO.File]::WriteAllText($bad, $helper.Replace("`$ErrorActionPreference = 'Stop'", ($mock + [Environment]::NewLine + "`$ErrorActionPreference = 'Stop'")), $utf8)
    $env:NNC_ELEVATE_INSTALLER = 'C:\invalid"path\telepites.bat'
    $env:NNC_ELEVATE_DESTINATION = 'C:\normal'
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & (Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe') -NoProfile -File $bad 2>$null
    $ErrorActionPreference = $oldPreference
    if ($LASTEXITCODE -eq 0) { throw 'Invalid path accepted' }
    Write-Host 'PASS: real BAT/helper/readable -File worker/CMD serialization; literal injection/Unicode/%/!/metacharacters; optional interactive destination; machine-stage flag; parent CDP continuation; child failure; cancellation; invalid path. RunAs mocked, no real UAC.'
} finally {
    foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
}


