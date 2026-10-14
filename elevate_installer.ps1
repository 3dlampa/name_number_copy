#Requires -Version 5.1
[CmdletBinding()]
param([string]$Payload = '')
$ErrorActionPreference = 'Stop'
try {
    if ($Payload) {
        # This is JSON data, not encoded PowerShell source.
        $data = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($Payload)) | ConvertFrom-Json
        $installer = [string]$data.Installer
        $destination = [string]$data.Destination
        $machineStageOnly = [bool]$data.MachineStageOnly
        $autoStart = [string]$data.AutoStart
    } else {
        $installer = $env:NNC_ELEVATE_INSTALLER
        $destination = $env:NNC_ELEVATE_DESTINATION
        $machineStageOnly = $env:NNC_ELEVATE_CHILD -eq '1'
        $autoStart = $env:NNC_AUTOSTART
    }
    if ($autoStart -notin @('On','Off')) { $autoStart = 'Off' }
    if ([string]::IsNullOrEmpty($installer) -or $installer -match '["\x00-\x1f]' -or $destination -match '["\x00-\x1f]' -or
        ($machineStageOnly -and [string]::IsNullOrEmpty($destination))) { throw 'Invalid installer or destination path.' }
    if (-not $Payload) {
        $json = @{ Installer=$installer; Destination=$destination; MachineStageOnly=$machineStageOnly; AutoStart=$autoStart } | ConvertTo-Json -Compress
        $serialized = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($json))
        $powershell = Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe'
        # Visible, readable -File entrypoint. Only the parameter data is Base64.
        $arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '" -Payload ' + $serialized
        $child = Start-Process -FilePath $powershell -ArgumentList $arguments -Verb RunAs -WindowStyle Normal -Wait -PassThru -ErrorAction Stop
        exit $child.ExitCode
    }
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = Join-Path ([Environment]::SystemDirectory) 'cmd.exe'
    $info.UseShellExecute = $false
    $info.EnvironmentVariables['NNC_REENTRY_INSTALLER'] = $installer
    $info.EnvironmentVariables['NNC_REENTRY_DESTINATION'] = $destination
    $info.EnvironmentVariables['NNC_AUTOSTART'] = $autoStart
    # Single expansion, no CALL reparse; delayed expansion remains disabled.
    $info.Arguments = if ($machineStageOnly) {
        '/d /v:off /s /c ""%NNC_REENTRY_INSTALLER%" "%NNC_REENTRY_DESTINATION%" /elevated-child"'
    } elseif ([string]::IsNullOrEmpty($destination)) {
        '/d /v:off /s /c ""%NNC_REENTRY_INSTALLER%""'
    } else { '/d /v:off /s /c ""%NNC_REENTRY_INSTALLER%" "%NNC_REENTRY_DESTINATION%""' }
    $child = [Diagnostics.Process]::Start($info)
    try { $child.WaitForExit(); $code = $child.ExitCode } finally { $child.Dispose() }
    exit $code
} catch { Write-Error $_; exit 1 }
