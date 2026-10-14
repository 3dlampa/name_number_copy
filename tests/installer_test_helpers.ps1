function Read-InstallerPrompt($Process, [string]$Prompt) {
    $text = New-Object Text.StringBuilder
    $buffer = New-Object char[] 1
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    while (-not $text.ToString().EndsWith($Prompt)) {
        $read = $Process.StandardOutput.ReadAsync($buffer,0,1)
        $remaining = [int]($deadline - [DateTime]::UtcNow).TotalMilliseconds
        if ($remaining -le 0 -or -not $read.Wait($remaining)) {
            $Process.Kill()
            throw "Installer prompt timeout: $Prompt / $text"
        }
        if ($read.Result -eq 0) { throw "Installer ended before prompt: $Prompt / $text" }
        $null = $text.Append($buffer[0])
    }
    return $text.ToString()
}
