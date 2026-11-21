[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('ClaretCore', 'ClaretHotbuild', 'ClaretUI')]
    [string]$Mod,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$Paths
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$gitRoot = (& git -C $repoRoot rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or (Resolve-Path -LiteralPath $gitRoot).Path -ne $repoRoot) {
    throw 'Скрипт должен находиться в корне Git-репозитория Claret.'
}

$branch = (& git -C $repoRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $branch -ne 'dev') {
    throw "Синхронизация разрешена только в ветке dev; текущая ветка: '$branch'."
}

$remote = (& git -C $repoRoot config --get remote.origin.url).Trim()
$allowedRemotes = @(
    'https://github.com/tfckatsu-cpu/Claret.git',
    'https://github.com/tfckatsu-cpu/Claret',
    'git@github.com:tfckatsu-cpu/Claret.git',
    'ssh://git@github.com/tfckatsu-cpu/Claret.git'
)
if ($LASTEXITCODE -ne 0 -or $remote -notin $allowedRemotes) {
    throw "Неожиданный remote origin: '$remote'. Синхронизация остановлена."
}

$gameRoot = Split-Path -Parent $repoRoot
$sourceRoot = Join-Path (Join-Path $gameRoot 'mods') $Mod
$mirrorRoot = Join-Path (Join-Path $repoRoot 'mods') $Mod
if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
    throw "Не найдена оригинальная папка мода: $sourceRoot"
}

function Get-GitBlobHash([string]$RepoPath, [string]$FilePath) {
    $hash = & git -C $repoRoot hash-object "--path=$RepoPath" -- $FilePath
    if ($LASTEXITCODE -ne 0) { throw "Не удалось проверить Git-файл: $RepoPath" }
    return $hash.Trim()
}

$plans = [System.Collections.Generic.List[object]]::new()
$seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

foreach ($inputPath in $Paths) {
    if ([System.IO.Path]::IsPathRooted($inputPath) -or $inputPath.Contains(':')) {
        throw "Нужен относительный путь внутри $Mod/: '$inputPath'"
    }

    $relativePath = $inputPath.Replace('/', '\')
    $segments = $relativePath.Split('\')
    if ($segments.Count -eq 0 -or $segments -contains '..' -or $segments -contains '.') {
        throw "Недопустимый путь: '$inputPath'"
    }
    if (-not $seen.Add($relativePath)) { continue }

    $sourcePath = [System.IO.Path]::GetFullPath((Join-Path $sourceRoot $relativePath))
    $mirrorPath = [System.IO.Path]::GetFullPath((Join-Path $mirrorRoot $relativePath))
    $sourcePrefix = $sourceRoot.TrimEnd('\') + '\'
    $mirrorPrefix = $mirrorRoot.TrimEnd('\') + '\'
    if (-not $sourcePath.StartsWith($sourcePrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not $mirrorPath.StartsWith($mirrorPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Путь выходит за пределы папки мода: '$inputPath'"
    }
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Оригинальный файл не найден. Удаления скрипт не синхронизирует: '$inputPath'"
    }

    $repoPath = "mods/$Mod/$($relativePath.Replace('\', '/'))"
    & git -C $repoRoot diff --cached --quiet HEAD -- $repoPath
    $stagedDiff = $LASTEXITCODE
    if ($stagedDiff -eq 1) {
        throw "Файл '$repoPath' уже staged. Сначала разберите его изменения отдельно."
    }
    if ($stagedDiff -ne 0) {
        throw "Не удалось проверить staged-состояние: $repoPath"
    }

    $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
    $mirrorExists = Test-Path -LiteralPath $mirrorPath -PathType Leaf
    $mirrorHash = $null
    if ($mirrorExists) {
        $mirrorHash = (Get-FileHash -LiteralPath $mirrorPath -Algorithm SHA256).Hash
        if ($mirrorHash -eq $sourceHash) {
            $plans.Add([pscustomobject]@{ Path = $inputPath; RepoPath = $repoPath; Source = $sourcePath; Mirror = $mirrorPath; Copy = $false })
            continue
        }
    }

    # A missing revision makes git write to stderr; under 'Stop' that aborts the
    # script, which used to break the first sync of every new file.
    $baseHash = $null
    try {
        $baseHash = & git -C $repoRoot rev-parse --verify "HEAD:$repoPath" 2>$null
    } catch {
        $baseHash = $null
    }
    $trackedAtHead = $LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($baseHash)
    if ($mirrorExists) {
        if (-not $trackedAtHead) {
            throw "В репозитории уже есть несохранённое зеркало '$repoPath'; проверьте конфликт вручную."
        }
        $currentGitHash = Get-GitBlobHash $repoPath $mirrorPath
        if ($currentGitHash -ne $baseHash.Trim()) {
            throw "Зеркало '$repoPath' изменено отдельно от оригинала. Конфликт не перезаписан."
        }
    } elseif ($trackedAtHead) {
        throw "Зеркало '$repoPath' отсутствует в рабочей папке. Конфликт не перезаписан."
    }

    $plans.Add([pscustomobject]@{ Path = $inputPath; RepoPath = $repoPath; Source = $sourcePath; Mirror = $mirrorPath; Copy = $true })
}

foreach ($plan in $plans) {
    if (-not $plan.Copy) {
        Write-Output "Уже синхронизирован: $($plan.RepoPath)"
        continue
    }
    if ($PSCmdlet.ShouldProcess($plan.RepoPath, 'Скопировать оригинал в репозиторное зеркало')) {
        $parent = Split-Path -Parent $plan.Mirror
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        Copy-Item -LiteralPath $plan.Source -Destination $plan.Mirror -Force
        $sourceHash = (Get-FileHash -LiteralPath $plan.Source -Algorithm SHA256).Hash
        $mirrorHash = (Get-FileHash -LiteralPath $plan.Mirror -Algorithm SHA256).Hash
        if ($sourceHash -ne $mirrorHash) {
            throw "Проверка SHA-256 после копирования не прошла: $($plan.RepoPath)"
        }
        Write-Output "Синхронизирован: $($plan.RepoPath)"
    }
}
