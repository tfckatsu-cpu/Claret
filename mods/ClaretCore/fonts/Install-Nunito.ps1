param([string]$GamePath, [switch]$DetectOnly, [switch]$Quiet)
$ErrorActionPreference = 'Stop'
$fontNames = @('Nunito-Regular.ttf', 'Nunito-SemiBold.ttf')

function Test-GameRoot([string]$Root) {
    return ($Root -and ((Test-Path -LiteralPath (Join-Path $Root 'bin\SupremeCommander.exe') -PathType Leaf) -or
        (Test-Path -LiteralPath (Join-Path $Root 'bin\ForgedAlliance.exe') -PathType Leaf)) -and
        (Test-Path -LiteralPath (Join-Path $Root 'fonts') -PathType Container))
}

function Find-GameRoot {
    $configs = @((Join-Path $env:APPDATA 'FAForever\FAForever Client\config\settings.json'))
    $fafFiles = @((Join-Path $env:ProgramData 'FAForever\fa_path.lua'))
    foreach ($config in $configs) {
        if (!(Test-Path -LiteralPath $config)) { continue }
        try {
            $settings = Get-Content -LiteralPath $config -Raw | ConvertFrom-Json
            if (Test-GameRoot $settings.paths.originalGameDir) { return $settings.paths.originalGameDir }
            if ($settings.gamePath) {
                $fafFiles = @((Join-Path (Split-Path (Split-Path $settings.gamePath)) 'fa_path.lua')) + $fafFiles
            }
        } catch { Write-Verbose "Cannot read client settings: $_" }
    }
    foreach ($file in $fafFiles) {
        if (!(Test-Path -LiteralPath $file)) { continue }
        # Read only a string assignment; never execute another application's Lua.
        $source = Get-Content -LiteralPath $file -Raw
        if ($source -match '(?m)^\s*fa_path\s*=\s*["'']([^"''\r\n]+)["'']') {
            $root = $Matches[1].Replace('\\', '\')
            if (Test-GameRoot $root) { return $root }
        }
    }
    return $null
}

try {
    if (!$GamePath) { $GamePath = Find-GameRoot }
    if ($DetectOnly) {
        if (!(Test-GameRoot $GamePath)) { throw 'Game folder was not found.' }
        Write-Output ([IO.Path]::GetFullPath($GamePath)); exit 0
    }
    if (!$GamePath -and !$Quiet) {
        Add-Type -AssemblyName System.Windows.Forms
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = 'Choose the Supreme Commander Forged Alliance folder containing bin and fonts.'
        $dialog.ShowNewFolderButton = $false
        try {
            if ($dialog.ShowDialog() -ne 'OK') { exit 0 }
            $GamePath = $dialog.SelectedPath
        } finally { $dialog.Dispose() }
    }
    if (!(Test-GameRoot $GamePath)) { throw 'Choose the game installation folder containing bin\ForgedAlliance.exe and fonts.' }
    $GamePath = [IO.Path]::GetFullPath($GamePath)
    $pending = @()
    foreach ($name in $fontNames) {
        $source = Join-Path $PSScriptRoot "Nunito\$name"
        $target = Join-Path $GamePath "fonts\$name"
        if (!(Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing bundled font: $name" }
        if (Test-Path -LiteralPath $target) {
            if ((Get-FileHash -LiteralPath $source).Hash -ne (Get-FileHash -LiteralPath $target).Hash) {
                throw "A different file already exists: $target. No files were changed."
            }
        } else { $pending += @{ Source = $source; Target = $target } }
    }
    $copied = @()
    try {
        foreach ($font in $pending) {
            # CreateNew avoids overwriting a file created since the preflight check.
            $output = [IO.File]::Open($font.Target, [IO.FileMode]::CreateNew)
            $copied += $font.Target
            try {
                $input = [IO.File]::OpenRead($font.Source)
                try { $input.CopyTo($output) } finally { $input.Dispose() }
            } finally { $output.Dispose() }
        }
    } catch {
        foreach ($file in $copied) { Remove-Item -LiteralPath $file -Force }
        throw
    }
    $message = "Nunito is installed in $GamePath\fonts.`nClose and reopen Forged Alliance. No special launch command is needed."
    Write-Output $message
    if (!$Quiet) {
        Add-Type -AssemblyName System.Windows.Forms
        [Windows.Forms.MessageBox]::Show($message, 'Claret Nunito') | Out-Null
    }
} catch {
    $message = "Nunito installation failed: $_`nIf access is denied, run Install-Nunito.cmd as administrator."
    if (!$Quiet) {
        Add-Type -AssemblyName System.Windows.Forms
        [Windows.Forms.MessageBox]::Show($message, 'Claret Nunito') | Out-Null
    }
    Write-Error $message -ErrorAction Continue
    exit 1
}
