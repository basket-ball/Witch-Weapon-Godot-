$ErrorActionPreference = 'Stop'

$projectRoot = Resolve-Path .
$bgBaseFs = Join-Path $projectRoot 'assets/images/bg'
$musicBaseFs = Join-Path $projectRoot 'assets/audio/music'

$bgFiles = Get-ChildItem -Recurse -File $bgBaseFs -Include *.png,*.jpg,*.jpeg,*.webp | Sort-Object FullName
$bgRoot = @()
$bgFolders = @{}
foreach ($f in $bgFiles) {
  $rel = $f.FullName.Substring($bgBaseFs.Length).TrimStart('\', '/') -replace '\\', '/'
  if ($rel -notmatch '/') { $bgRoot += $rel; continue }
  $parts = $rel.Split('/', 2)
  $folder = $parts[0]
  $inside = $parts[1]
  if (-not $bgFolders.ContainsKey($folder)) { $bgFolders[$folder] = @() }
  $bgFolders[$folder] += $inside
}
$bgFoldersOrdered = [ordered]@{}
foreach ($k in ($bgFolders.Keys | Sort-Object)) {
  $bgFoldersOrdered[$k] = @($bgFolders[$k] | Sort-Object)
}

$musicFiles = Get-ChildItem -Recurse -File $musicBaseFs -Include *.ogg,*.mp3,*.wav | Sort-Object FullName
$musicRel = @()
foreach ($f in $musicFiles) {
  $rel = $f.FullName.Substring($musicBaseFs.Length).TrimStart('\', '/') -replace '\\', '/'
  $musicRel += $rel
}

$obj = [ordered]@{
  version = 1
  generated_from = 'filesystem'
  backgrounds = [ordered]@{
    base_dir = 'res://assets/images/bg/'
    root = @($bgRoot | Sort-Object)
    folders = $bgFoldersOrdered
  }
  music = [ordered]@{
    base_dir = 'res://assets/audio/music/'
    files = @($musicRel | Sort-Object)
  }
}

$outPath = Join-Path $projectRoot 'assets/mod_editor_resource_index.json'
$json = $obj | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($outPath, $json, [System.Text.Encoding]::UTF8)

Write-Output "Wrote $outPath"
