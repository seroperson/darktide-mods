$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path output | Out-Null
foreach ($dir in Get-ChildItem -Directory) {
    $modFile = Get-ChildItem -Path $dir.FullName -Filter "$($dir.Name).mod" -File -ErrorAction SilentlyContinue
    if (-not $modFile) { continue }
    $modName = $dir.Name
    $content = Get-Content $modFile.FullName -Raw
    if ($content -match 'version\s*=\s*"([^"]+)"') {
        $zipName = "${modName}-$($Matches[1]).zip"
    } else {
        $zipName = "${modName}.zip"
    }
    Write-Host "Building $zipName..."
    $zipPath = "output/$zipName"
    if (Test-Path $zipPath) { Remove-Item $zipPath }
    Compress-Archive -Path $modName -DestinationPath $zipPath
}
