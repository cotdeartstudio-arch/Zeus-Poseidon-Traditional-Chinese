param([ValidateSet('Install','Check','Restore')][string]$Mode='Install',[string]$GameDir,[string]$BackupDir)
$ErrorActionPreference='Stop'
Write-Host '【重要】安裝前務必自行備份完整遊戲資料夾與玩家存檔！' -ForegroundColor Yellow
Write-Host '自動備份僅涵蓋補丁變更的檔案，不能取代完整備份。' -ForegroundColor Yellow
Write-Host '本補丁免費提供，僅供已合法持有原版遊戲的玩家使用。'
Write-Host '適用於 Steam 英文版 Zeus + Poseidon；非官方漢化補丁。'
if ($Mode -eq 'Restore') { Write-Host '還原需使用本次安裝建立的 ZH-Patch-Backup-v2.2-時間 備份資料夾。' -ForegroundColor Yellow }

function Hash([string]$p) { (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant() }
function SafePath([string]$root,[string]$rel) {
 if ([IO.Path]::IsPathRooted($rel) -or ($rel -split '[/\\]') -contains '..') { throw 'Unsafe manifest path' }
 $p=[IO.Path]::GetFullPath((Join-Path $root $rel))
 if (-not $p.StartsWith($root.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Path outside destination' }
 return $p
}
if (-not $GameDir) { $GameDir=Read-Host '請輸入含有 zeus.exe 的遊戲資料夾完整路徑' }
$GameDir=(Resolve-Path -LiteralPath $GameDir.Trim('"')).Path
if (-not (Test-Path -LiteralPath (Join-Path $GameDir 'zeus.exe'))) { throw 'zeus.exe not found' }
if ($Mode -ne 'Check') { foreach ($proc in (Get-Process -Name zeus,zeus-zh -ErrorAction SilentlyContinue)) { if (-not $proc.Path -or [IO.Path]::GetDirectoryName($proc.Path) -eq $GameDir) { throw '請先關閉此資料夾中的遊戲。' } } }
$manifest=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($Mode -eq 'Restore') {
 if (-not $BackupDir) { $BackupDir=Read-Host '請輸入安裝時產生的備份資料夾完整路徑' }
 $BackupDir=(Resolve-Path -LiteralPath $BackupDir.Trim('"')).Path
 $state=Get-Content -LiteralPath (Join-Path $BackupDir 'backup.json') -Raw -Encoding UTF8 | ConvertFrom-Json
 if ($state.game -ne $GameDir -or $state.version -ne '2.2') { throw 'Backup does not belong to this game folder/version' }
 $operations=@()
 foreach ($f in $state.files) {
  $dst=SafePath $GameDir $f.path;$src=SafePath $BackupDir $f.path
  if ((Hash $dst) -ne $f.patched -or (Hash $src) -ne $f.original) { throw "File changed after install or damaged backup: $($f.path)" }
  $operations+=@{src=$src;dst=$dst;hash=$f.original}
 }
 foreach ($f in $state.disabled) {
  $dst=SafePath $GameDir $f.path;$src=$dst+'.ZH-v2.2-disabled'
  if (Test-Path -LiteralPath $dst) { throw 'Chinese resource already exists; refusing overwrite' }
  if ((Hash $src) -ne $f.original) { throw 'Disabled resource changed' }
 }
 foreach ($op in $operations) { Copy-Item -LiteralPath $op.src -Destination $op.dst -Force;if ((Hash $op.dst) -ne $op.hash) { throw 'Restore verification failed' } }
 foreach ($f in $state.disabled) { $dst=SafePath $GameDir $f.path;Move-Item -LiteralPath ($dst+'.ZH-v2.2-disabled') -Destination $dst }
 Write-Host '原版檔案已還原，存檔與設定保持不變。';exit
}
$disable=@()
foreach ($f in $manifest.optional_disable) {
 $dst=SafePath $GameDir $f.path
 if (Test-Path -LiteralPath $dst) {
  if ((Hash $dst) -ne $f.original -or (Test-Path -LiteralPath ($dst+'.ZH-v2.2-disabled'))) { throw 'Unsupported Chinese resource or conflicting backup' }
  $disable+=$f
 }
}
$already=$true
foreach ($f in $manifest.files) {
 $src=SafePath $PSScriptRoot $f.delta;$dst=SafePath $GameDir $f.path
 if ((Hash $src) -ne $f.delta_sha256) { throw "補丁損壞：$($f.path)" }
 $actual=Hash $dst
 if ($actual -ne $f.patched) { $already=$false }
 if ($actual -ne $f.original -and $actual -ne $f.patched) { throw "不相容或已被修改的遊戲檔案： $($f.path). 尚未安裝任何檔案。" }
}
if ($already) { Write-Host '已經完整安裝此版本補丁。';exit }
foreach ($f in $manifest.files) { if ((Hash (SafePath $GameDir $f.path)) -ne $f.original) { throw '發現原版與補丁檔案混用，請先還原乾淨的支援版本。' } }
$Stage=Join-Path ([IO.Path]::GetTempPath()) ('Zeus-ZH-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Stage | Out-Null
try {
Add-Type -Path (Join-Path $PSScriptRoot 'Delta.cs')
foreach ($f in $manifest.files) {
 $target=SafePath $Stage $f.path
 New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
 [ZhDelta]::Apply((SafePath $GameDir $f.path),(SafePath $PSScriptRoot $f.delta),$target)
 if ((Hash $target) -ne $f.patched) { throw "補丁重建校驗失敗：$($f.path)" }
}
Write-Host '相容性與 16 個檔案重建校驗通過。'
if ($Mode -eq 'Check') { exit }
$BackupDir=Join-Path $GameDir ('ZH-Patch-Backup-v2.2-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
if (Test-Path -LiteralPath $BackupDir) { throw 'Backup folder already exists' }
New-Item -ItemType Directory -Path $BackupDir | Out-Null
foreach ($f in $manifest.files) {
 $dst=SafePath $BackupDir $f.path;New-Item -ItemType Directory -Path (Split-Path $dst) -Force | Out-Null
 Copy-Item -LiteralPath (SafePath $GameDir $f.path) -Destination $dst
 if ((Hash $dst) -ne $f.original) { throw 'Backup verification failed. No game files installed.' }
}
@{version='2.2';game=$GameDir;files=$manifest.files;disabled=$disable} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $BackupDir 'backup.json') -Encoding UTF8
$done=@()
$renamed=@()
try {
 foreach ($f in $disable) { $dst=SafePath $GameDir $f.path;Move-Item -LiteralPath $dst -Destination ($dst+'.ZH-v2.2-disabled');$renamed+=$f }
 foreach ($f in $manifest.files) {
  $dst=SafePath $GameDir $f.path;$done+=$f
  Copy-Item -LiteralPath (SafePath $Stage $f.path) -Destination $dst -Force
  if ((Hash $dst) -ne $f.patched) { throw "Verification failed: $($f.path)" }
 }
} catch {
 foreach ($f in $done) { Copy-Item -LiteralPath (SafePath $BackupDir $f.path) -Destination (SafePath $GameDir $f.path) -Force }
 foreach ($f in $renamed) { $dst=SafePath $GameDir $f.path;Move-Item -LiteralPath ($dst+'.ZH-v2.2-disabled') -Destination $dst }
 throw
}
Write-Host 'V2.2 漢化補丁安裝完成，存檔與設定保持不變。'
Write-Host "Backup: $BackupDir"

} finally {
 # Stage is an internally generated GUID directory, never user-supplied.
 if ($Stage -and (Test-Path -LiteralPath $Stage)) { Remove-Item -LiteralPath $Stage -Recurse -Force }
}
