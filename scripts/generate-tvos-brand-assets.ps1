# Recreates the original Trentfinity VPN tvOS artwork using vector geometry.
# Requires PowerShell 7 on Windows and System.Drawing; no image source or
# downloaded artwork is used. Asset names and dimensions stay upstream-compatible.
param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$assetRoot = Join-Path $ProjectRoot 'NetBird TV/Assets.xcassets'
$brandSource = Join-Path $PSScriptRoot 'branding'
New-Item -ItemType Directory -Force -Path $brandSource | Out-Null

$navy = [System.Drawing.ColorTranslator]::FromHtml('#081321')
$navyLight = [System.Drawing.ColorTranslator]::FromHtml('#102A43')
$cyan = [System.Drawing.ColorTranslator]::FromHtml('#6DE7E0')
$teal = [System.Drawing.ColorTranslator]::FromHtml('#26BFB4')
$white = [System.Drawing.ColorTranslator]::FromHtml('#EDF9FF')
$muted = [System.Drawing.ColorTranslator]::FromHtml('#7796AC')

function New-Path([string]$Kind) {
    $p = [System.Drawing.Drawing2D.GraphicsPath]::new()
    if ($Kind -eq 'shield') {
        $p.AddLine([single]0.5,[single]0.06,[single]0.88,[single]0.20)
        $p.AddLine([single]0.88,[single]0.20,[single]0.85,[single]0.57)
        $p.AddBezier([single]0.85,[single]0.57,[single]0.81,[single]0.75,[single]0.66,[single]0.88,[single]0.5,[single]0.95)
        $p.AddBezier([single]0.5,[single]0.95,[single]0.34,[single]0.88,[single]0.19,[single]0.75,[single]0.15,[single]0.57)
        $p.AddLine([single]0.15,[single]0.57,[single]0.12,[single]0.20)
        $p.CloseFigure()
    } else {
        $p.AddBezier([single]0.5,[single]0.44,[single]0.38,[single]0.18,[single]0.22,[single]0.24,[single]0.22,[single]0.44)
        $p.AddBezier([single]0.22,[single]0.44,[single]0.22,[single]0.64,[single]0.38,[single]0.70,[single]0.5,[single]0.44)
        $p.AddBezier([single]0.5,[single]0.44,[single]0.62,[single]0.18,[single]0.78,[single]0.24,[single]0.78,[single]0.44)
        $p.AddBezier([single]0.78,[single]0.44,[single]0.78,[single]0.64,[single]0.62,[single]0.70,[single]0.5,[single]0.44)
    }
    return ,$p
}

function Draw-Mark($g,[single]$X,[single]$Y,[single]$Size,$Outline=$cyan,$Inside=$white) {
    $saved = $g.Save()
    $g.TranslateTransform($X,$Y)
    $g.ScaleTransform($Size,$Size)
    $shield = New-Path 'shield'
    $infinity = New-Path 'infinity'
    $outlinePen = [System.Drawing.Pen]::new($Outline,[single]0.035)
    $insidePen = [System.Drawing.Pen]::new($Inside,[single]0.065)
    $stemPen = [System.Drawing.Pen]::new($Inside,[single]0.065)
    foreach ($pen in @($outlinePen,$insidePen,$stemPen)) {
        $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
        $pen.StartCap = $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    }
    $g.DrawPath($outlinePen,$shield)
    $g.DrawPath($insidePen,$infinity)
    $g.DrawLine($stemPen,[single]0.5,[single]0.49,[single]0.5,[single]0.75)
    $shield.Dispose(); $infinity.Dispose()
    $outlinePen.Dispose(); $insidePen.Dispose(); $stemPen.Dispose()
    $g.Restore($saved)
}

function Draw-Text($g,[string]$Text,[single]$Size,[single]$X,[single]$Y,$Color,[bool]$Centered=$false,[bool]$Bold=$true) {
    $style = if ($Bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $font = [System.Drawing.Font]::new('Segoe UI',$Size,$style,[System.Drawing.GraphicsUnit]::Pixel)
    $brush = [System.Drawing.SolidBrush]::new($Color)
    $format = [System.Drawing.StringFormat]::GenericTypographic.Clone()
    $format.FormatFlags = [System.Drawing.StringFormatFlags]::NoWrap
    if ($Centered) { $X -= $g.MeasureString($Text,$font,10000,$format).Width / 2 }
    $g.DrawString($Text,$font,$brush,$X,$Y,$format)
    $format.Dispose(); $brush.Dispose(); $font.Dispose()
}

function Draw-Background($g,[int]$Width,[int]$Height,[bool]$Decorated=$true) {
    $rect = [System.Drawing.Rectangle]::new(0,0,$Width,$Height)
    $brush = [System.Drawing.Drawing2D.LinearGradientBrush]::new($rect,$navy,$navyLight,[single]25)
    $g.FillRectangle($brush,$rect)
    $brush.Dispose()
    if ($Decorated) {
        $pen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(24,$teal),[single]([math]::Max(1,$Width/800)))
        foreach ($radius in @(.72,1.03,1.34)) {
            $r = $Height*$radius
            $g.DrawEllipse($pen,[single]($Width*.83-$r),[single]($Height*.15-$r),[single](2*$r),[single](2*$r))
        }
        $pen.Dispose()
    }
}

function Write-Asset([string]$File,[int]$Width,[int]$Height,[string]$Kind,[bool]$Dark=$true) {
    $transparent = $Kind -in @('foreground','menu','button','empty')
    $format = if ($transparent) { [System.Drawing.Imaging.PixelFormat]::Format32bppArgb } else { [System.Drawing.Imaging.PixelFormat]::Format24bppRgb }
    # Render small shapes at 3x to keep their curves and thin strokes smooth.
    $sample = if ($Width -le 800) { 3 } else { 1 }
    $large = [System.Drawing.Bitmap]::new($Width*$sample,$Height*$sample,$format)
    $g = [System.Drawing.Graphics]::FromImage($large)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.ScaleTransform($sample,$sample)
    if ($transparent) { $g.Clear([System.Drawing.Color]::Transparent) }
    switch ($Kind) {
        'background' { Draw-Background $g $Width $Height $false }
        'middle' { Draw-Background $g $Width $Height $true }
        'foreground' {
            $size = $Height*.61
            Draw-Mark $g ($Width/2-$size/2) ($Height*.07) $size
            Draw-Text $g 'Trentfinity VPN' ($Height*.107) ($Width/2) ($Height*.755) $white $true
        }
        'shelf' {
            Draw-Background $g $Width $Height $true
            # Keep the wordmark group within the common central TV safe area.
            $groupWidth = $Height*1.98
            $left = ($Width-$groupWidth)/2
            Draw-Mark $g $left ($Height*.21) ($Height*.54)
            Draw-Text $g 'Trentfinity' ($Height*.145) ($left+$Height*.62) ($Height*.285) $white
            Draw-Text $g 'VPN' ($Height*.066) ($left+$Height*.63) ($Height*.49) $cyan $false $false
        }
        'menu' {
            $textColor = if ($Dark) { $white } else { $navy }
            $markColor = if ($Dark) { $cyan } else { $teal }
            $unit = $Width/150
            Draw-Mark $g (0*$unit) (1*$unit) (32*$unit) $markColor $markColor
            Draw-Text $g 'Trentfinity' (17*$unit) (38*$unit) (1*$unit) $textColor
            Draw-Text $g 'VPN' (9*$unit) (39*$unit) (23*$unit) $markColor $false $false
        }
        'button' {
            $state = $g.Save()
            $g.TranslateTransform([single](-$Width*.15),[single](-$Height*.06))
            $g.ScaleTransform([single]($Width*1.3),[single]($Height*1.3))
            $p = New-Path 'infinity'
            $pen = [System.Drawing.Pen]::new($cyan,[single]0.105)
            $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
            $g.DrawPath($pen,$p)
            $p.Dispose(); $pen.Dispose(); $g.Restore($state)
        }
        'empty' {
            $pen = [System.Drawing.Pen]::new($muted,[single]2.4)
            $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
            $g.DrawLine($pen,[single]35,[single]55,[single]90,[single]30)
            $g.DrawLine($pen,[single]90,[single]30,[single]145,[single]55)
            $g.DrawLine($pen,[single]35,[single]55,[single]90,[single]85)
            $g.DrawLine($pen,[single]145,[single]55,[single]90,[single]85)
            $fill = [System.Drawing.SolidBrush]::new($navyLight)
            foreach ($point in @(@(35,55),@(90,30),@(145,55),@(90,85))) {
                $g.FillEllipse($fill,[single]($point[0]-8),[single]($point[1]-8),[single]16,[single]16)
                $g.DrawEllipse($pen,[single]($point[0]-8),[single]($point[1]-8),[single]16,[single]16)
            }
            $fill.Dispose(); $pen.Dispose()
        }
    }
    $g.Dispose()
    if ($sample -gt 1) {
        $output = [System.Drawing.Bitmap]::new($Width,$Height,$format)
        $smallGraphics = [System.Drawing.Graphics]::FromImage($output)
        $smallGraphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $smallGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $smallGraphics.DrawImage($large,[System.Drawing.Rectangle]::new(0,0,$Width,$Height))
        $smallGraphics.Dispose(); $large.Dispose()
    } else { $output = $large }
    $output.Save($File,[System.Drawing.Imaging.ImageFormat]::Png)
    $output.Dispose()
}

$manifest = @()
foreach ($asset in Get-ChildItem -LiteralPath $assetRoot -Recurse -File -Filter '*.png') {
    $old = [System.Drawing.Image]::FromFile($asset.FullName)
    $w = $old.Width; $h = $old.Height; $old.Dispose()
    $rel = [System.IO.Path]::GetRelativePath($assetRoot,$asset.FullName).Replace('\','/')
    $kind = switch -Regex ($rel) {
        'netbird-logo-menu.imageset' { 'menu'; break }
        'icon-netbird-button.imageset' { 'button'; break }
        'icon-empty-box.imageset' { 'empty'; break }
        '/Top Shelf Image[^/]*\.imageset/' { 'shelf'; break }
        'Back.imagestacklayer' { 'background'; break }
        'App Icon - App Store.imagestack/Middle' { 'foreground'; break }
        'Middle.imagestacklayer' { 'middle'; break }
        'Front.imagestacklayer' { 'foreground'; break }
        default { throw "Unrecognized asset: $rel" }
    }
    Write-Asset $asset.FullName $w $h $kind ($asset.BaseName.EndsWith(' 1'))
    $manifest += [ordered]@{path=$rel;width=$w;height=$h;kind=$kind;sha256=(Get-FileHash -LiteralPath $asset.FullName -Algorithm SHA256).Hash.ToLower()}
}

# Store the original vector mark alongside its reproducible renderer.
@'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" fill="none" stroke-linecap="round" stroke-linejoin="round">
  <title>Trentfinity VPN original shield and infinity mark</title>
  <path stroke="#6DE7E0" stroke-width="3.5" d="M50 6L88 20L85 57C81 75 66 88 50 95C34 88 19 75 15 57L12 20Z"/>
  <path stroke="#EDF9FF" stroke-width="6.5" d="M50 44C38 18 22 24 22 44C22 64 38 70 50 44C62 18 78 24 78 44C78 64 62 70 50 44"/>
  <path stroke="#EDF9FF" stroke-width="6.5" d="M50 49V75"/>
</svg>
'@ | Set-Content -LiteralPath (Join-Path $brandSource 'trentfinity-mark.svg') -Encoding utf8
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $brandSource 'asset-manifest.json') -Encoding utf8
@'
{"colors":[{"color":{"color-space":"srgb","components":{"alpha":"1.000","blue":"0.878","green":"0.906","red":"0.427"}},"idiom":"universal"}],"info":{"author":"xcode","version":1}}
'@ | Set-Content -LiteralPath (Join-Path $assetRoot 'AccentColor.colorset/Contents.json') -Encoding utf8

# Preview composites transparent layers over their real backgrounds.
$preview = [System.Drawing.Bitmap]::new(1440,900)
$pg = [System.Drawing.Graphics]::FromImage($preview)
$pg.Clear($navy)
$pg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
Draw-Text $pg 'TRENTFINITY VPN  /  TV ASSETS' 22 45 25 $muted
$shelf = [System.Drawing.Image]::FromFile((Join-Path $assetRoot 'App Icon & Top Shelf Image.brandassets/Top Shelf Image Wide.imageset/top-shelf-wide.png'))
$pg.DrawImage($shelf,[System.Drawing.Rectangle]::new(40,80,1360,422)); $shelf.Dispose()
Draw-Text $pg 'HOME SCREEN ICON' 16 45 535 $muted
foreach ($layer in @('Middle','Front')) {
    $img = [System.Drawing.Image]::FromFile((Join-Path $assetRoot "App Icon & Top Shelf Image.brandassets/App Icon.imagestack/$layer.imagestacklayer/Content.imageset/netbird-tvos-icon@2x.png"))
    $pg.DrawImage($img,[System.Drawing.Rectangle]::new(45,580,400,240)); $img.Dispose()
}
Draw-Text $pg 'NAVIGATION  /  DARK AND LIGHT' 16 530 535 $muted
$lightBrush = [System.Drawing.SolidBrush]::new($white)
$pg.FillRectangle($lightBrush,530,720,380,100); $lightBrush.Dispose()
foreach ($item in @(@('netbird-logo-menu@2x 1.png',600),@('netbird-logo-menu@2x.png',735))) {
    $img = [System.Drawing.Image]::FromFile((Join-Path $assetRoot ('netbird-logo-menu.imageset/'+$item[0])))
    $pg.DrawImage($img,[System.Drawing.Rectangle]::new(560,$item[1],301,74)); $img.Dispose()
}
Draw-Text $pg 'SMALL ACTION / EMPTY STATE' 16 970 535 $muted
$img = [System.Drawing.Image]::FromFile((Join-Path $assetRoot 'icon-netbird-button.imageset/icon-netbird-button@3x.png'))
$pg.DrawImage($img,1010,610,42,42); $img.Dispose()
$img = [System.Drawing.Image]::FromFile((Join-Path $assetRoot 'icon-empty-box.imageset/icon-empty-box.png'))
$pg.DrawImage($img,1100,700,181,110); $img.Dispose()
$pg.Dispose()
$preview.Save((Join-Path $brandSource 'trentfinity-brand-preview.png'),[System.Drawing.Imaging.ImageFormat]::Png)
$preview.Dispose()
Write-Output "Generated $($manifest.Count) original tvOS PNG assets."
