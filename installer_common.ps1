#Requires -Version 5.1
function Get-InstallerLocations([string]$TestRoot) {
    if ($TestRoot) {
        $desktop = Join-Path $TestRoot 'PublicDesktop'
        $programs = Join-Path $TestRoot 'CommonPrograms'
        $startup = Join-Path $TestRoot 'CommonStartup'
    } else {
        $desktop = [Environment]::GetFolderPath('CommonDesktopDirectory')
        $programs = [Environment]::GetFolderPath('CommonPrograms')
        $startup = [Environment]::GetFolderPath('CommonStartup')
    }
    if (-not $desktop -or -not $programs -or -not $startup) { throw 'Nem erhetoek el a kozos Windows mappak.' }
    return @{ Desktop = $desktop; Menu = (Join-Path $programs 'OpenCart Rendelesmasolo'); Startup = $startup }
}

function Test-OwnedShortcut([string]$Path, [string]$InstallDir) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    $link = (New-Object -ComObject WScript.Shell).CreateShortcut($Path)
    $exe = Join-Path $InstallDir 'name - number copy.exe'
    if ($link.TargetPath -eq $exe) { return $true }
    # Compatibility with this installer's old PowerShell shortcuts; unrelated links are retained.
    $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $script = '"' + (Join-Path $InstallDir 'start_opencart_browser.ps1') + '"'
    return ($link.TargetPath -eq $ps -and $link.Arguments.Contains($script))
}

function Remove-OwnedShortcut([string]$Path, [string]$InstallDir) {
    if (Test-OwnedShortcut $Path $InstallDir) { Remove-Item -LiteralPath $Path -Force -ErrorAction Stop }
}
