$ErrorActionPreference = 'Stop'

try {
    # Paths are data throughout the PowerShell and elevated CMD boundaries.
    $installer = $env:NNC_ELEVATE_INSTALLER
    $destination = $env:NNC_ELEVATE_DESTINATION
    $machineStageOnly = $env:NNC_ELEVATE_CHILD -eq '1'
    if ([string]::IsNullOrEmpty($installer) -or $installer -match '["\x00-\x1f]' -or $destination -match '["\x00-\x1f]' -or
        ($machineStageOnly -and [string]::IsNullOrEmpty($destination))) {
        throw 'Invalid installer or destination path.'
    }
    $payload = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes(
        (@{ Installer = $installer; Destination = $destination; MachineStageOnly = $machineStageOnly } | ConvertTo-Json -Compress)))
    # Only Base64 data is inserted; path text never becomes command source.
    $bootstrap = @'
$ErrorActionPreference = 'Stop'
try {
    $data = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('__PAYLOAD__')) | ConvertFrom-Json
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = Join-Path ([Environment]::SystemDirectory) 'cmd.exe'
    $info.UseShellExecute = $false
    $info.EnvironmentVariables['NNC_REENTRY_INSTALLER'] = [string]$data.Installer
    $info.EnvironmentVariables['NNC_REENTRY_DESTINATION'] = [string]$data.Destination
    # A single expansion, no CALL reparse; delayed expansion stays disabled.
    $info.Arguments = if ([bool]$data.MachineStageOnly) {
        '/d /v:off /s /c ""%NNC_REENTRY_INSTALLER%" "%NNC_REENTRY_DESTINATION%" /elevated-child"'
    } elseif ([string]::IsNullOrEmpty([string]$data.Destination)) {
        '/d /v:off /s /c ""%NNC_REENTRY_INSTALLER%""'
    } else {
        '/d /v:off /s /c ""%NNC_REENTRY_INSTALLER%" "%NNC_REENTRY_DESTINATION%""'
    }
    $child = [Diagnostics.Process]::Start($info)
    try { $child.WaitForExit(); $code = $child.ExitCode } finally { $child.Dispose() }
    exit $code
} catch {
    Write-Error $_
    exit 1
}
'@
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($bootstrap.Replace('__PAYLOAD__', $payload)))
    $powershell = Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe'
    $child = Start-Process -FilePath $powershell -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -EncodedCommand ' + $encoded) -Verb RunAs -WindowStyle Hidden -Wait -PassThru -ErrorAction Stop
    exit $child.ExitCode
} catch {
    Write-Error $_
    exit 1
}
