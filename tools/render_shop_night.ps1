# Renders the shops of the development island with Blender (tools/render_shop_night_previews.py).
#   & .\tools\render_shop_night.ps1 -Out <dir>            day renders of the originals
#   & .\tools\render_shop_night.ps1 -Out <dir> -Night     night renders, each original next to its night copy
#   -Only general-mini,candy-a   only these shops
param([Parameter(Mandatory)] [string] $Out, [switch] $Night, [switch] $Originals, [string[]] $Only)
$repo = Split-Path $PSScriptRoot -Parent
$blender = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
$shops = 'general-mini', 'flower-a', 'general-orange-b', 'general-orange-a', 'building-multi', 'townhouse-blue',
    'general-brick', 'steel-glass', 'candy-a', 'candy-b', 'coffee-a', 'coffee-b', 'general-generic', 'townhouse-gabled'
if ($Only) { $shops = $Only }
New-Item -ItemType Directory -Force $Out | Out-Null
$groups = foreach ($s in $shops) {
    $o = "$repo\shops\models\shop-$s.glb"
    if ($Night -and -not $Originals) { "$o+$repo\shops\models\shop-${s}_night.glb" } else { $o }
}
$flag = if ($Night) { '1' } else { '0' }
Write-Host "=== rendering $($shops.Count) shops to $Out ===" -ForegroundColor Cyan
& $blender -b -P "$repo\tools\render_shop_night_previews.py" -- $Out $flag @groups 2>&1 |
    Where-Object { $_ -match 'Saved:|Error|Traceback' }
Write-Host 'RENDER DONE' -ForegroundColor Green
