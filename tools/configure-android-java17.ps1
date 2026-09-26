$ErrorActionPreference = 'Stop'
# Use a locally installed JDK 17. No Gradle 9 migration and no system Java removal.
$candidates = @()
if ($env:JAVA_HOME) { $candidates += $env:JAVA_HOME }
foreach ($root in @("$env:ProgramFiles\Eclipse Adoptium", "$env:ProgramFiles\Microsoft", "$env:ProgramFiles\Java", "$env:ProgramFiles\Android\Android Studio\jbr")) {
  if (Test-Path "$root\bin\java.exe") { $candidates += $root }
  if (Test-Path $root) { $candidates += Get-ChildItem $root -Directory | Select-Object -ExpandProperty FullName }
}
$selected = $null
foreach ($candidate in $candidates) {
  $release = Join-Path $candidate 'release'
  if ((Test-Path $release) -and ((Get-Content $release -Raw) -match 'JAVA_VERSION="17[.\"]')) { $selected=$candidate; break }
}
if (!$selected) {
  Write-Host 'JDK 17 was not found. Install Eclipse Temurin 17 JDK, then run this file again.'
  Write-Host 'Optional Windows install command: winget install --id EclipseAdoptium.Temurin.17.JDK -e'
  exit 1
}
$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (!$flutter) { throw 'Flutter is not in PATH. Open your Flutter terminal and run this script again.' }
& $flutter.Source config --jdk-dir $selected
if ($LASTEXITCODE -ne 0) { throw 'Flutter could not save the JDK selection.' }
$projectRoot = Split-Path $PSScriptRoot -Parent
$gradleDir = Join-Path $projectRoot 'mobile\android\.gradle'
New-Item -ItemType Directory -Force $gradleDir | Out-Null
$escaped = $selected.Replace('\','/')
Set-Content -Encoding ASCII (Join-Path $gradleDir 'config.properties') "java.home=$escaped"
Write-Host "Flutter now uses JDK 17: $selected"
Write-Host 'In Android Studio: Settings > Build Tools > Gradle > Gradle JDK: select the same JDK 17.'
Write-Host 'Restart Android Studio, then run the Android device again.'
