$ErrorActionPreference = "SilentlyContinue"
$s = New-Object -ComObject WScript.Shell
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Recent" -Filter "*.lnk" |
  Sort-Object LastWriteTime -Descending | Select-Object -First 25 | ForEach-Object {
    $l = $s.CreateShortcut($_.FullName)
    if ($l -and $l.TargetPath -match "art_|review|ticket|记录") {
      Write-Host ("RECENT " + $_.LastWriteTime.ToString("MM-dd HH:mm") + " " + $_.BaseName + " -> " + $l.TargetPath)
    }
  }
foreach ($b in @("Google\Chrome\User Data\Default", "Google\Chrome\User Data\Profile 1", "Microsoft\Edge\User Data\Default")) {
  $p = Join-Path $env:LOCALAPPDATA ($b + "\Preferences")
  if (Test-Path $p) {
    try {
      $json = Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json
      $dir = $json.download.default_directory
      Write-Host ("BROWSER " + $b + " download_dir = " + $(if ($dir) { $dir } else { "(默认 Downloads)" }))
    } catch { Write-Host ("BROWSER " + $b + " prefs parse fail") }
  }
}
