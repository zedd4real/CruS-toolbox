$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$src = "C:\Users\asus\crus_toolbox_dev\MOD_CONTENT\CruS Toolbox"
$out = "C:\Users\asus\crus_toolbox_dev\mod.zip"
$files = @("init.gd", "toolbox.gd")

if (Test-Path $out) { Remove-Item $out -Force }

$fs = [System.IO.File]::Open($out, [System.IO.FileMode]::Create)
$zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($f in $files) {
        $entry = $zip.CreateEntry("MOD_CONTENT/CruS Toolbox/$f", [System.IO.Compression.CompressionLevel]::Optimal)
        $es = $entry.Open()
        $bytes = [System.IO.File]::ReadAllBytes((Join-Path $src $f))
        $es.Write($bytes, 0, $bytes.Length)
        $es.Dispose()
    }
}
finally {
    $zip.Dispose()
    $fs.Dispose()
}
Write-Host "wrote $out"
