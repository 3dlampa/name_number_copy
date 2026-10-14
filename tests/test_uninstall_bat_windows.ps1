$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
. (Join-Path $root 'tests/installer_test_helpers.ps1')
$uacMock = @'
function Start-Process {
    param($FilePath,$ArgumentList,$Verb,$WindowStyle,[switch]$Wait,[switch]$PassThru,$ErrorAction)
    if ($Verb -ne 'RunAs' -or $WindowStyle -ne 'Normal') { throw 'Unexpected UAC contract' }
    if ($env:NNC_REMOVE_CANCEL -eq '1') { throw 'Simulated UAC cancellation' }
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $FilePath
    $info.Arguments = $ArgumentList
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $child = [Diagnostics.Process]::Start($info)
    try { $child.WaitForExit(); $code=$child.ExitCode } finally { $child.Dispose() }
    return [pscustomobject]@{ExitCode=$code}
}
'@
foreach ($mode in @('direct','uac','cancel')) {
    $stage = Join-Path $env:RUNNER_TEMP ('nnc-remove-bat-' + $mode + '-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    foreach ($file in @('installer_common.ps1','uninstall.ps1','eltavolitas.bat','elevate_installer.ps1')) {
        Copy-Item -LiteralPath (Join-Path $root $file) -Destination $stage
    }
    [IO.File]::WriteAllText((Join-Path $stage 'installation_manifest.json'),(@{Product='NameNumberCopy';InstallDir=$stage;Version='test'}|ConvertTo-Json))
    $entry = Join-Path $stage 'eltavolitas.bat'
    $text = [IO.File]::ReadAllText($entry).Replace('-InstallDir "%REMOVE_DIR%"','-InstallDir "%REMOVE_DIR%" -TestRoot "%NNC_REMOVE_MACHINE%"')
    # Only the actual OS UAC gate/RunAs call and known-folder roots are mocked.
    $text = $text.Replace('fltmc >nul 2>&1','cmd.exe /d /c exit 1')
    [IO.File]::WriteAllText($entry,$text,(New-Object Text.UTF8Encoding($false)))
    $helper = Join-Path $stage 'elevate_installer.ps1'
    $text = [IO.File]::ReadAllText($helper).Replace("`$ErrorActionPreference = 'Stop'",($uacMock + [Environment]::NewLine + "`$ErrorActionPreference = 'Stop'"))
    [IO.File]::WriteAllText($helper,$text,(New-Object Text.UTF8Encoding($true)))
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $env:ComSpec
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.EnvironmentVariables['NNC_REMOVE_DIR'] = $stage
    $info.EnvironmentVariables['NNC_REMOVE_MACHINE'] = Join-Path $stage 'FakeMachine'
    $info.EnvironmentVariables['NNC_REMOVE_CANCEL'] = if ($mode -eq 'cancel') { '1' } else { '0' }
    $info.Arguments = if ($mode -eq 'direct') {
        '/d /v:off /s /c ""%NNC_REMOVE_DIR%\eltavolitas.bat" "%NNC_REMOVE_DIR%" /elevated-child"'
    } else { '/d /v:off /s /c ""%NNC_REMOVE_DIR%\eltavolitas.bat""' }
    $process = [Diagnostics.Process]::Start($info)
    $promptText = ''
    if ($mode -ne 'direct') {
        $promptText = Read-InstallerPrompt $process 'Eltavolitod? (I/N): '
        $process.StandardInput.WriteLine('I')
    }
    $process.StandardInput.Close()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(30000)) {
        $process.Kill($true)
        throw "Owned test uninstaller timed out: $mode"
    }
    $output = $promptText + $stdoutTask.GetAwaiter().GetResult()
    $errors = $stderrTask.GetAwaiter().GetResult()
    $expectedCode = if ($mode -eq 'cancel') { 1 } else { 0 }
    if ($process.ExitCode -ne $expectedCode) { throw "BAT removal $mode / $($process.ExitCode): $output $errors" }
    $process.Dispose()
    $manifestRemaining = Test-Path -LiteralPath (Join-Path $stage 'installation_manifest.json')
    if ($mode -eq 'cancel') {
        if (-not $manifestRemaining -or -not (Test-Path -LiteralPath $entry)) { throw 'Cancelled UAC modified installation' }
    } elseif ($manifestRemaining -or (Test-Path -LiteralPath $entry) -or $errors) { throw "BAT removal left files or stderr: $errors" }
}
Write-Host 'PASS: real uninstall BAT exits 0 after deleting itself; direct and mocked-UAC paths; UAC cancellation retains installation.'
