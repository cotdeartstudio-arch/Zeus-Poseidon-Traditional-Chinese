param([ValidateSet('Restore')][string]$Mode='Restore',[string]$GameDir,[string]$BackupDir)
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
