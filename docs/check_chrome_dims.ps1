Add-Type -AssemblyName System.Drawing
$root = "F:\godot fair duet\create\phase-war\assets\cards"
foreach ($sub in @("backgrounds","frames")) {
    $dir = Join-Path $root $sub
    Write-Output "=== $sub ==="
    Get-ChildItem "$dir\*.png" -ErrorAction SilentlyContinue | ForEach-Object {
        $img = [System.Drawing.Image]::FromFile($_.FullName)
        $ratio = [math]::Round($img.Width / $img.Height, 3)
        Write-Output ("{0}  {1}x{2}  ratio={3}" -f $_.Name, $img.Width, $img.Height, $ratio)
        $img.Dispose()
    }
}
