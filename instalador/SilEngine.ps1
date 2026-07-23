#Requires -Version 5.1
<#
  Motor compartilhado do instalador S.I.L. (CLI e interface visual).
  Dot-source: . "$PSScriptRoot\SilEngine.ps1"
#>

$script:SilScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$script:SilDefaultRepoRoot = (Resolve-Path (Join-Path $script:SilScriptDir '..')).Path

function Sil-Log {
  param([string]$Message, [ValidateSet('info','ok','warn','err','step')]$Level = 'info')
  if ($script:SilLogHandler) {
    & $script:SilLogHandler $Message $Level
  } else {
    switch ($Level) {
      'step' { Write-Host ""; Write-Host "==> $Message" -ForegroundColor Cyan }
      'ok'   { Write-Host "    OK  $Message" -ForegroundColor Green }
      'warn' { Write-Host "    !!  $Message" -ForegroundColor Yellow }
      'err'  { Write-Host "    XX  $Message" -ForegroundColor Red }
      default { Write-Host "    $Message" }
    }
  }
}

function Sil-SetStep {
  param([string]$Id, [ValidateSet('pending','running','done','error','skipped')]$Status, [string]$Detail = '')
  if ($script:SilStepHandler) {
    & $script:SilStepHandler $Id $Status $Detail
  }
}

function Sil-GetLanIPv4 {
  $addrs = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object {
      $_.IPAddress -notlike '127.*' -and
      $_.IPAddress -notlike '169.254.*' -and
      $_.PrefixOrigin -ne 'WellKnown'
    } | Sort-Object InterfaceMetric
  return @($addrs | Select-Object -ExpandProperty IPAddress -Unique)
}

function Sil-FindFlutterBin([string]$hint) {
  $candidates = @()
  if ($hint) { $candidates += $hint }
  $candidates += @('D:\flutter\bin', 'C:\flutter\bin', "$env:LOCALAPPDATA\flutter\bin", "$env:USERPROFILE\flutter\bin")
  foreach ($c in $candidates) {
    if ($c -and (Test-Path (Join-Path $c 'flutter.bat'))) { return (Resolve-Path $c).Path }
    if ($c -and (Test-Path (Join-Path $c 'dart.bat'))) { return (Resolve-Path $c).Path }
  }
  $cmd = Get-Command flutter -ErrorAction SilentlyContinue
  if ($cmd) { return (Split-Path $cmd.Source -Parent) }
  $cmd = Get-Command dart -ErrorAction SilentlyContinue
  if ($cmd) { return (Split-Path $cmd.Source -Parent) }
  return $null
}

function Sil-EnsureFlutter([string]$flutterBin) {
  if (-not $flutterBin) { throw 'Flutter/Dart nao encontrado. Informe o caminho (ex.: D:\flutter\bin).' }
  $env:Path = "$flutterBin;" + $env:Path
  $flutter = Join-Path $flutterBin 'flutter.bat'
  $dart = Join-Path $flutterBin 'dart.bat'
  if (-not (Test-Path $flutter) -and -not (Test-Path $dart)) {
    throw "Nem flutter.bat nem dart.bat em: $flutterBin"
  }
  return @{
    Flutter = $(if (Test-Path $flutter) { $flutter } else { $null })
    Dart    = $(if (Test-Path $dart) { $dart } else { $null })
  }
}

# Flutter/Dart escrevem progresso em stderr ("Building flutter tool...").
# Com $ErrorActionPreference=Stop isso vira excecao fatal no PowerShell.
function Sil-InvokeNative {
  param(
    [Parameter(Mandatory)][string]$FilePath,
    [string[]]$ArgumentList = @(),
    [switch]$LogOutput
  )
  if (-not (Test-Path -LiteralPath $FilePath)) {
    throw "Executavel nao encontrado: $FilePath"
  }
  $oldEa = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $output = & $FilePath @ArgumentList 2>&1
    $code = $LASTEXITCODE
    foreach ($line in @($output)) {
      $text = if ($line -is [System.Management.Automation.ErrorRecord]) {
        [string]$line.Exception.Message
      } else {
        [string]$line
      }
      if ([string]::IsNullOrWhiteSpace($text)) { continue }
      if ($LogOutput) {
        Sil-Log $text 'info'
      }
    }
    return $code
  } finally {
    $ErrorActionPreference = $oldEa
  }
}

function Sil-EnableTls12 {
  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  } catch {}
}

function Sil-DefaultToolsRoot {
  foreach ($c in @('D:\SIL_tools', 'C:\SIL_tools', (Join-Path $env:LOCALAPPDATA 'SIL_tools'))) {
    $parent = Split-Path $c -Parent
    if ($parent -and (Test-Path $parent)) { return $c }
  }
  return (Join-Path $env:LOCALAPPDATA 'SIL_tools')
}

function Sil-FindJavaHome {
  if ($env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME 'bin\java.exe'))) {
    return $env:JAVA_HOME
  }
  $candidates = @(
    (Join-Path (Sil-DefaultToolsRoot) 'jdk'),
    (Join-Path $env:LOCALAPPDATA 'SIL_tools\jdk'),
    'C:\Program Files\Microsoft\jdk-17*',
    'C:\Program Files\Eclipse Adoptium\jdk-17*',
    'C:\Program Files\Java\jdk-17*'
  )
  foreach ($pattern in $candidates) {
    $hits = @(Get-Item $pattern -ErrorAction SilentlyContinue | Sort-Object FullName -Descending)
    foreach ($h in $hits) {
      if (Test-Path (Join-Path $h.FullName 'bin\java.exe')) { return $h.FullName }
    }
  }
  $cmd = Get-Command java -ErrorAction SilentlyContinue
  if ($cmd) {
    $bin = Split-Path $cmd.Source -Parent
    $home = Split-Path $bin -Parent
    if (Test-Path (Join-Path $home 'bin\java.exe')) { return $home }
  }
  return $null
}

function Sil-FindAndroidSdk {
  $candidates = @(
    $env:ANDROID_HOME,
    $env:ANDROID_SDK_ROOT,
    (Join-Path $env:LOCALAPPDATA 'Android\Sdk'),
    (Join-Path $env:USERPROFILE 'AppData\Local\Android\Sdk'),
    'C:\Android\Sdk',
    (Join-Path (Sil-DefaultToolsRoot) 'android-sdk')
  )
  foreach ($c in $candidates) {
    if (-not $c) { continue }
    $pt = Join-Path $c 'platform-tools'
    $platforms = Join-Path $c 'platforms'
    if ((Test-Path $pt) -or (Test-Path $platforms)) { return $c }
  }
  return $null
}

function Sil-FindAdb {
  $cmd = Get-Command adb -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $sdk = Sil-FindAndroidSdk
  if ($sdk) {
    $adb = Join-Path $sdk 'platform-tools\adb.exe'
    if (Test-Path $adb) { return $adb }
  }
  return $null
}

function Sil-AndroidSdkReady([string]$sdkRoot) {
  if (-not $sdkRoot) { return $false }
  $adb = Join-Path $sdkRoot 'platform-tools\adb.exe'
  $platforms = Join-Path $sdkRoot 'platforms'
  $buildTools = Join-Path $sdkRoot 'build-tools'
  return (Test-Path $adb) -and (Test-Path $platforms) -and (Test-Path $buildTools) -and
    (@(Get-ChildItem $platforms -Directory -ErrorAction SilentlyContinue).Count -gt 0) -and
    (@(Get-ChildItem $buildTools -Directory -ErrorAction SilentlyContinue).Count -gt 0)
}

function Sil-ProbePrerequisites {
  param(
    [hashtable]$Cfg,
    [bool]$NeedApk = $true,
    [bool]$NeedAdb = $false
  )
  $flutterBin = Sil-FindFlutterBin $(if ($Cfg) { $Cfg.flutterBin } else { $null })
  $javaHome = Sil-FindJavaHome
  $androidSdk = Sil-FindAndroidSdk
  $adb = Sil-FindAdb
  $missing = New-Object System.Collections.Generic.List[string]

  if (-not $flutterBin) {
    $missing.Add('Flutter/Dart SDK')
  }
  if ($NeedApk) {
    if (-not $javaHome) { $missing.Add('JDK 17 (Java)') }
    if (-not (Sil-AndroidSdkReady $androidSdk)) { $missing.Add('Android SDK (plataformas + build-tools)') }
  } elseif ($NeedAdb -and -not $adb) {
    $missing.Add('ADB (Android platform-tools)')
  }

  return @{
    Missing     = @($missing)
    FlutterBin  = $flutterBin
    JavaHome    = $javaHome
    AndroidSdk  = $androidSdk
    AdbPath     = $adb
    Ok          = ($missing.Count -eq 0)
  }
}

function Sil-DownloadFile([string]$Url, [string]$OutFile) {
  Sil-EnableTls12
  $dir = Split-Path $OutFile -Parent
  if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  Sil-Log "Baixando: $Url" 'info'
  Sil-Log "Destino: $OutFile" 'info'
  $tmp = "$OutFile.download"
  try {
    if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
      Start-BitsTransfer -Source $Url -Destination $tmp -ErrorAction Stop
    } else {
      $wc = New-Object System.Net.WebClient
      $wc.Headers.Add('User-Agent', 'SIL-Installer/1.0')
      $wc.DownloadFile($Url, $tmp)
      $wc.Dispose()
    }
    if (Test-Path $OutFile) { Remove-Item -Force $OutFile }
    Move-Item -Force $tmp $OutFile
  } catch {
    if (Test-Path $tmp) { Remove-Item -Force $tmp -ErrorAction SilentlyContinue }
    # Fallback Invoke-WebRequest
    try {
      Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -UserAgent 'SIL-Installer/1.0'
    } catch {
      throw "Falha ao baixar $Url : $($_.Exception.Message)"
    }
  }
  if (-not (Test-Path $OutFile)) { throw "Arquivo nao baixado: $OutFile" }
  $sizeMb = [math]::Round((Get-Item $OutFile).Length / 1MB, 1)
  Sil-Log "Download concluido ($sizeMb MB)" 'ok'
}

function Sil-ExpandZip([string]$ZipPath, [string]$DestDir) {
  if (-not (Test-Path $DestDir)) {
    New-Item -ItemType Directory -Force -Path $DestDir | Out-Null
  }
  Sil-Log "Extraindo: $ZipPath" 'info'
  $tar = Get-Command tar.exe -ErrorAction SilentlyContinue
  if ($tar) {
    & tar.exe -xf $ZipPath -C $DestDir
    if ($LASTEXITCODE -ne 0) { throw "tar falhou ao extrair $ZipPath" }
  } else {
    Expand-Archive -Path $ZipPath -DestinationPath $DestDir -Force
  }
  Sil-Log 'Extracao concluida' 'ok'
}

function Sil-GetFlutterStableDownload {
  Sil-EnableTls12
  $manifestUrl = 'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json'
  Sil-Log 'Consultando manifesto Flutter (stable)...' 'info'
  $json = Invoke-RestMethod -Uri $manifestUrl -TimeoutSec 60
  $hash = $json.current_release.stable
  $rel = @($json.releases | Where-Object { $_.hash -eq $hash -and $_.channel -eq 'stable' }) | Select-Object -First 1
  if (-not $rel) {
    $rel = @($json.releases | Where-Object { $_.channel -eq 'stable' }) | Select-Object -First 1
  }
  if (-not $rel) { throw 'Nao foi possivel localizar release stable do Flutter.' }
  $base = if ($json.base_url -match 'flutter_infra_release') {
    $json.base_url.TrimEnd('/')
  } else {
    'https://storage.googleapis.com/flutter_infra_release/releases'
  }
  return @{
    Version = [string]$rel.version
    Url     = "$base/$($rel.archive)"
  }
}

function Sil-InstallFlutterSdk([string]$toolsRoot, [bool]$dryRun) {
  $flutterRoot = Join-Path $toolsRoot 'flutter'
  $bin = Join-Path $flutterRoot 'bin'
  if ((Test-Path (Join-Path $bin 'flutter.bat')) -or (Test-Path (Join-Path $bin 'dart.bat'))) {
    Sil-Log "Flutter ja presente em $bin" 'ok'
    return $bin
  }
  $info = Sil-GetFlutterStableDownload
  Sil-Log "Flutter stable $($info.Version)" 'info'
  if ($dryRun) {
    Sil-Log "DryRun: baixaria Flutter de $($info.Url) para $flutterRoot" 'warn'
    return $bin
  }
  $zip = Join-Path $env:TEMP "flutter_windows_$($info.Version).zip"
  Sil-DownloadFile -Url $info.Url -OutFile $zip
  if (-not (Test-Path $toolsRoot)) {
    New-Item -ItemType Directory -Force -Path $toolsRoot | Out-Null
  }
  # zip contem pasta "flutter"
  if (Test-Path $flutterRoot) {
    throw "Pasta $flutterRoot ja existe e esta incompleta. Remova e tente de novo."
  }
  Sil-ExpandZip -ZipPath $zip -DestDir $toolsRoot
  Remove-Item -Force $zip -ErrorAction SilentlyContinue
  if (-not (Test-Path (Join-Path $bin 'flutter.bat'))) {
    throw "Flutter extraiu, mas flutter.bat nao encontrado em $bin"
  }
  Sil-Log "Flutter instalado em $bin" 'ok'
  # Primeira execucao compila o flutter_tool (pode demorar; progresso vai para stderr)
  Sil-Log 'Preparando Flutter tool (primeira execucao)...' 'info'
  $prepCode = Sil-InvokeNative -FilePath (Join-Path $bin 'flutter.bat') -ArgumentList @('--version') -LogOutput
  if ($prepCode -ne 0) {
    throw "Falha ao preparar Flutter tool (codigo $prepCode). Rode: `"$bin\flutter.bat`" --version"
  }
  Sil-Log 'Flutter tool pronto' 'ok'
  return $bin
}

function Sil-InstallJdk([string]$toolsRoot, [bool]$dryRun) {
  $jdkRoot = Join-Path $toolsRoot 'jdk'
  if (Test-Path (Join-Path $jdkRoot 'bin\java.exe')) {
    Sil-Log "JDK ja presente em $jdkRoot" 'ok'
    return $jdkRoot
  }
  $url = 'https://aka.ms/download-jdk/microsoft-jdk-17-windows-x64.zip'
  if ($dryRun) {
    Sil-Log "DryRun: baixaria JDK 17 de $url para $jdkRoot" 'warn'
    return $jdkRoot
  }
  $zip = Join-Path $env:TEMP 'sil-microsoft-jdk-17.zip'
  Sil-DownloadFile -Url $url -OutFile $zip
  $extract = Join-Path $env:TEMP 'sil-jdk-extract'
  if (Test-Path $extract) { Remove-Item -Recurse -Force $extract }
  New-Item -ItemType Directory -Force -Path $extract | Out-Null
  Sil-ExpandZip -ZipPath $zip -DestDir $extract
  Remove-Item -Force $zip -ErrorAction SilentlyContinue
  $found = Get-ChildItem $extract -Recurse -Filter 'java.exe' -ErrorAction SilentlyContinue |
    Where-Object { $_.Directory.Name -eq 'bin' } |
    Select-Object -First 1
  if (-not $found) { throw 'JDK baixado, mas java.exe nao encontrado no zip.' }
  $srcHome = $found.Directory.Parent.FullName
  if (Test-Path $jdkRoot) { Remove-Item -Recurse -Force $jdkRoot }
  New-Item -ItemType Directory -Force -Path (Split-Path $jdkRoot -Parent) | Out-Null
  Move-Item -Path $srcHome -Destination $jdkRoot
  Remove-Item -Recurse -Force $extract -ErrorAction SilentlyContinue
  Sil-Log "JDK instalado em $jdkRoot" 'ok'
  return $jdkRoot
}

function Sil-InstallAndroidSdk([string]$sdkRoot, [bool]$needFullSdk, [bool]$dryRun) {
  if (-not $sdkRoot) { $sdkRoot = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
  if ($dryRun) {
    Sil-Log "DryRun: instalaria Android SDK em $sdkRoot" 'warn'
    return $sdkRoot
  }
  New-Item -ItemType Directory -Force -Path $sdkRoot | Out-Null

  $adb = Join-Path $sdkRoot 'platform-tools\adb.exe'
  if (-not (Test-Path $adb)) {
    $ptZip = Join-Path $env:TEMP 'sil-platform-tools.zip'
    Sil-DownloadFile -Url 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip' -OutFile $ptZip
    Sil-ExpandZip -ZipPath $ptZip -DestDir $sdkRoot
    Remove-Item -Force $ptZip -ErrorAction SilentlyContinue
    Sil-Log 'Android platform-tools instalado' 'ok'
  }

  if (-not $needFullSdk) { return $sdkRoot }
  if (Sil-AndroidSdkReady $sdkRoot) {
    Sil-Log "Android SDK pronto em $sdkRoot" 'ok'
    return $sdkRoot
  }

  $sdkManager = $null
  $latestBin = Join-Path $sdkRoot 'cmdline-tools\latest\bin\sdkmanager.bat'
  if (Test-Path $latestBin) {
    $sdkManager = $latestBin
  } else {
    $ctZip = Join-Path $env:TEMP 'sil-cmdline-tools.zip'
    # Pacote oficial Google (commandlinetools Windows)
    Sil-DownloadFile -Url 'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip' -OutFile $ctZip
    $tmpCt = Join-Path $env:TEMP 'sil-cmdline-extract'
    if (Test-Path $tmpCt) { Remove-Item -Recurse -Force $tmpCt }
    New-Item -ItemType Directory -Force -Path $tmpCt | Out-Null
    Sil-ExpandZip -ZipPath $ctZip -DestDir $tmpCt
    Remove-Item -Force $ctZip -ErrorAction SilentlyContinue
    $inner = Join-Path $tmpCt 'cmdline-tools'
    if (-not (Test-Path $inner)) {
      $inner = Get-ChildItem $tmpCt -Directory | Select-Object -First 1 -ExpandProperty FullName
    }
    $dest = Join-Path $sdkRoot 'cmdline-tools\latest'
    New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
    Move-Item -Path $inner -Destination $dest
    Remove-Item -Recurse -Force $tmpCt -ErrorAction SilentlyContinue
    $sdkManager = Join-Path $dest 'bin\sdkmanager.bat'
    if (-not (Test-Path $sdkManager)) { throw "sdkmanager.bat nao encontrado em $dest" }
    Sil-Log 'Android cmdline-tools instalado' 'ok'
  }

  Sil-Log 'Instalando componentes Android SDK (pode demorar)...' 'info'
  $sdkCmd = "`"$sdkManager`" --sdk_root=$sdkRoot platform-tools `"platforms;android-35`" `"platforms;android-34`" `"build-tools;35.0.0`" `"build-tools;34.0.0`""
  cmd.exe /c $sdkCmd 2>&1 | ForEach-Object { Sil-Log ([string]$_) 'info' }

  # Aceitar licencas
  $licenseIn = Join-Path $env:TEMP 'sil-sdk-licenses-in.txt'
  (('y' + "`r`n") * 40) | Set-Content -Path $licenseIn -Encoding ASCII
  $licOut = Join-Path $env:TEMP 'sil-sdk-licenses-out.txt'
  cmd.exe /c "`"$sdkManager`" --sdk_root=$sdkRoot --licenses < `"$licenseIn`" > `"$licOut`" 2>&1" | Out-Null
  Sil-Log 'Licencas Android SDK processadas' 'ok'

  if (-not (Sil-AndroidSdkReady $sdkRoot)) {
    throw "Android SDK incompleto em $sdkRoot. Verifique rede/proxy e tente de novo."
  }
  Sil-Log "Android SDK pronto em $sdkRoot" 'ok'
  return $sdkRoot
}

function Sil-ApplyToolEnv([string]$flutterBin, [string]$javaHome, [string]$androidSdk) {
  if ($flutterBin) { $env:Path = "$flutterBin;" + $env:Path }
  if ($javaHome) {
    $env:JAVA_HOME = $javaHome
    $env:Path = "$(Join-Path $javaHome 'bin');" + $env:Path
  }
  if ($androidSdk) {
    $env:ANDROID_HOME = $androidSdk
    $env:ANDROID_SDK_ROOT = $androidSdk
    $pt = Join-Path $androidSdk 'platform-tools'
    if (Test-Path $pt) { $env:Path = "$pt;" + $env:Path }
  }
}

function Sil-EnsurePrerequisites {
  param(
    [hashtable]$Cfg,
    [bool]$NeedApk = $true,
    [bool]$NeedAdb = $false,
    [bool]$AllowDownload = $false,
    [bool]$DryRun = $false
  )

  $probe = Sil-ProbePrerequisites -Cfg $Cfg -NeedApk:$NeedApk -NeedAdb:$NeedAdb
  if ($probe.Ok) {
    if ($probe.FlutterBin) { $Cfg.flutterBin = $probe.FlutterBin }
    Sil-ApplyToolEnv -flutterBin $Cfg.flutterBin -javaHome $probe.JavaHome -androidSdk $probe.AndroidSdk
    Sil-Log 'Pre-requisitos ja instalados neste computador.' 'ok'
    return (Sil-EnsureFlutter $Cfg.flutterBin)
  }

  $lista = ($probe.Missing -join ', ')
  Sil-Log "Faltando: $lista" 'warn'

  if (-not $AllowDownload) {
    throw "Pre-requisitos ausentes ($lista). Rode o instalador e confirme o download, ou instale manualmente."
  }

  if ($DryRun) {
    Sil-Log "DryRun: com confirmacao, baixaria: $lista" 'warn'
  } else {
    Sil-Log 'Usuario confirmou download automatico dos pre-requisitos.' 'info'
  }

  $toolsRoot = Sil-DefaultToolsRoot
  Sil-Log "Pasta de ferramentas: $toolsRoot" 'info'

  if (-not $probe.FlutterBin) {
    Sil-SetStep 'prereq' 'running' 'Baixando Flutter/Dart'
    $Cfg.flutterBin = Sil-InstallFlutterSdk -toolsRoot $toolsRoot -dryRun:$DryRun
  } else {
    $Cfg.flutterBin = $probe.FlutterBin
  }

  $javaHome = $probe.JavaHome
  if ($NeedApk -and -not $javaHome) {
    Sil-SetStep 'prereq' 'running' 'Baixando JDK 17'
    $javaHome = Sil-InstallJdk -toolsRoot $toolsRoot -dryRun:$DryRun
  }

  $androidSdk = $probe.AndroidSdk
  if (-not $androidSdk) {
    $androidSdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
  }
  $needSdk = $NeedApk -or ($NeedAdb -and -not $probe.AdbPath)
  if ($needSdk -and (($NeedApk -and -not (Sil-AndroidSdkReady $androidSdk)) -or ($NeedAdb -and -not $probe.AdbPath))) {
    Sil-SetStep 'prereq' 'running' 'Baixando Android SDK'
    $androidSdk = Sil-InstallAndroidSdk -sdkRoot $androidSdk -needFullSdk:$NeedApk -dryRun:$DryRun
  }

  if (-not $DryRun) {
    Sil-ApplyToolEnv -flutterBin $Cfg.flutterBin -javaHome $javaHome -androidSdk $androidSdk
    $flutterBat = Join-Path $Cfg.flutterBin 'flutter.bat'
    if ((Test-Path $flutterBat) -and $androidSdk) {
      $cfgCode = Sil-InvokeNative -FilePath $flutterBat -ArgumentList @('config', "--android-sdk=$androidSdk")
      if ($cfgCode -ne 0) {
        Sil-Log "flutter config --android-sdk retornou codigo $cfgCode (seguindo)" 'warn'
      }
    }
  }

  # Revalidar (em dry-run aceita caminhos previstos)
  if ($DryRun) {
    Sil-Log 'DryRun: pre-requisitos seriam instalados; seguindo simulacao.' 'warn'
    return @{
      Flutter = $(if ($Cfg.flutterBin) { Join-Path $Cfg.flutterBin 'flutter.bat' } else { $null })
      Dart    = $(if ($Cfg.flutterBin) { Join-Path $Cfg.flutterBin 'dart.bat' } else { $null })
    }
  }

  $probe2 = Sil-ProbePrerequisites -Cfg $Cfg -NeedApk:$NeedApk -NeedAdb:$NeedAdb
  if (-not $probe2.Ok) {
    throw "Ainda faltam pre-requisitos apos download: $($probe2.Missing -join ', ')"
  }
  $Cfg.flutterBin = $probe2.FlutterBin
  Sil-ApplyToolEnv -flutterBin $Cfg.flutterBin -javaHome $probe2.JavaHome -androidSdk $probe2.AndroidSdk
  return (Sil-EnsureFlutter $Cfg.flutterBin)
}

function Sil-IsAdmin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Sil-EnsureFirewall([int]$port, [bool]$dryRun) {
  $name = "S.I.L. API $port"
  if ($dryRun) { Sil-Log "DryRun: regra firewall '$name'" 'warn'; return }
  if (-not (Sil-IsAdmin)) {
    Sil-Log 'Sem privilegio de Administrador - firewall nao alterado.' 'warn'
    Sil-Log "Execute como Admin ou: netsh advfirewall firewall add rule name=`"$name`" dir=in action=allow protocol=TCP localport=$port" 'warn'
    return
  }
  netsh advfirewall firewall delete rule name="$name" 2>$null | Out-Null
  netsh advfirewall firewall add rule name="$name" dir=in action=allow protocol=TCP localport=$port | Out-Null
  Sil-Log "Firewall liberado na porta $port" 'ok'
}

function Sil-EnsureJunction([string]$repoRoot, [string]$buildDir, [bool]$dryRun) {
  if ($repoRoot -notmatch '\s') { return $repoRoot }
  Sil-Log "Caminho com espaco - usando junction: $buildDir" 'warn'
  if ($dryRun) { return $buildDir }
  if (Test-Path $buildDir) {
    $item = Get-Item $buildDir -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
      return (Resolve-Path $buildDir).Path
    }
    throw "Ja existe $buildDir e nao e junction. Remova ou escolha outro buildDir."
  }
  $parent = Split-Path $buildDir -Parent
  if ($parent -and -not (Test-Path $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
  cmd /c "mklink /J `"$buildDir`" `"$repoRoot`"" | Out-Null
  return (Resolve-Path $buildDir).Path
}

function Sil-WriteApiStartScript([hashtable]$cfg, [string]$outPath, [bool]$dryRun) {
  $lines = @(
    '# Auto-gerado pelo instalador S.I.L.'
    "`$ErrorActionPreference = 'Stop'"
    "`$env:Path = '$($cfg.flutterBin);' + `$env:Path"
    "`$env:SIL_API_HOST = '$($cfg.apiHost)'"
    "`$env:SIL_API_PORT = '$($cfg.apiPort)'"
    "`$env:SIL_WINTHOR_PROVIDER = '$($cfg.winthorProvider)'"
  )
  if ($cfg.winthorProvider -eq 'oracle') {
    $lines += "`$env:SIL_ORACLE_CONN = '$($cfg.oracleConn)'"
    $lines += "`$env:SIL_ORACLE_USER = '$($cfg.oracleUser)'"
    $lines += "`$env:SIL_ORACLE_PASSWORD = '$($cfg.oraclePassword)'"
  }
  $apiDir = Join-Path $cfg.repoRoot 'api'
  $lines += "Set-Location '$apiDir'"
  $lines += "Write-Host 'S.I.L. API http://$($cfg.apiPublicIp):$($cfg.apiPort) (winthor=$($cfg.winthorProvider))' -ForegroundColor Cyan"
  $lines += "& '$($cfg.flutterBin)\dart.bat' run bin/server.dart"
  if ($dryRun) { Sil-Log "DryRun: escreveria $outPath" 'warn'; return }
  $utf8Bom = New-Object System.Text.UTF8Encoding $true
  [System.IO.File]::WriteAllText($outPath, (($lines -join "`r`n") + "`r`n"), $utf8Bom)
  Sil-Log "Script da API: $outPath" 'ok'
}

function Sil-StartupShortcut([string]$startScript, [string]$clienteNome, [bool]$dryRun) {
  $startup = [Environment]::GetFolderPath('Startup')
  $lnkPath = Join-Path $startup "SIL-API-$clienteNome.lnk"
  if ($dryRun) { Sil-Log "DryRun: atalho $lnkPath" 'warn'; return }
  $w = New-Object -ComObject WScript.Shell
  $lnk = $w.CreateShortcut($lnkPath)
  $lnk.TargetPath = 'powershell.exe'
  $lnk.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$startScript`""
  $lnk.WorkingDirectory = Split-Path $startScript -Parent
  $lnk.WindowStyle = 1
  $lnk.Description = "S.I.L. API - $clienteNome"
  $lnk.Save()
  Sil-Log "Atalho de inicializacao: $lnkPath" 'ok'
}

function Sil-ApiDeps([string]$repoRoot, [hashtable]$tools, [bool]$dryRun) {
  $api = Join-Path $repoRoot 'api'
  if (-not (Test-Path (Join-Path $api 'pubspec.yaml'))) { throw "Pasta api nao encontrada em $repoRoot" }
  if ($dryRun) { Sil-Log 'DryRun: dart pub get' 'warn'; return }
  Push-Location $api
  try {
    $code = Sil-InvokeNative -FilePath $tools.Dart -ArgumentList @('pub', 'get') -LogOutput
    if ($code -ne 0) { throw "dart pub get falhou (codigo $code)" }
    Sil-Log 'Dependencias da API instaladas' 'ok'
  } finally { Pop-Location }
}

function Sil-StartApi([string]$startScript, [int]$port, [bool]$dryRun) {
  if ($dryRun) { Sil-Log "DryRun: iniciaria $startScript" 'warn'; return }
  $existing = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
  if ($existing) {
    Sil-Log "Ja existe processo na porta $port - mantido." 'warn'
    return
  }
  Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$startScript`""
  Start-Sleep -Seconds 3
  Sil-Log 'API iniciada em nova janela' 'ok'
}

function Sil-Health([string]$ip, [int]$port) {
  $url = "http://${ip}:${port}/health"
  try {
    $r = Invoke-RestMethod -Uri $url -TimeoutSec 5
    Sil-Log "Health $url -> status=$($r.status) winthor=$($r.winthor)" 'ok'
    return $true
  } catch {
    Sil-Log "Health falhou ($url): $($_.Exception.Message)" 'warn'
    return $false
  }
}

function Sil-BuildApk([hashtable]$cfg, [hashtable]$tools, [bool]$dryRun) {
  if (-not $tools.Flutter) { throw 'flutter.bat necessario para gerar o APK' }
  $work = Sil-EnsureJunction -repoRoot $cfg.repoRoot -buildDir $cfg.buildDir -dryRun:$dryRun
  $baseUrl = "http://$($cfg.apiPublicIp):$($cfg.apiPort)"
  Sil-Log "Build APK ($baseUrl)" 'step'
  if ($dryRun) {
    Sil-Log "DryRun: flutter build apk --dart-define=SIL_API_BASE_URL=$baseUrl" 'warn'
    return $null
  }
  Push-Location $work
  try {
    $pubCode = Sil-InvokeNative -FilePath $tools.Flutter -ArgumentList @('pub', 'get') -LogOutput
    if ($pubCode -ne 0) { throw "flutter pub get falhou (codigo $pubCode)" }
    $buildArgs = if ($cfg.apkRelease) {
      @('build', 'apk', '--release', "--dart-define=SIL_API_BASE_URL=$baseUrl")
    } else {
      @('build', 'apk', '--debug', "--dart-define=SIL_API_BASE_URL=$baseUrl")
    }
    $buildCode = Sil-InvokeNative -FilePath $tools.Flutter -ArgumentList $buildArgs -LogOutput
    if ($buildCode -ne 0) { throw "flutter build apk falhou (codigo $buildCode)" }
    $apkName = if ($cfg.apkRelease) { 'app-release.apk' } else { 'app-debug.apk' }
    $apk = Join-Path $work "build\app\outputs\flutter-apk\$apkName"
    if (-not (Test-Path $apk)) { throw "APK nao encontrado: $apk" }
    $destDir = Join-Path $script:SilScriptDir 'saida'
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    $safeName = ($cfg.clienteNome -replace '[^\w\-]', '_')
    $dest = Join-Path $destDir "SIL-$safeName-$($cfg.apiPublicIp)-$apkName"
    Copy-Item -Force $apk $dest
    Sil-Log "APK: $dest" 'ok'
    return $dest
  } finally { Pop-Location }
}

function Sil-InstallAdb([string]$apkPath, [bool]$dryRun) {
  $adbPath = Sil-FindAdb
  if (-not $adbPath) {
    Sil-Log 'adb nao encontrado - copie o APK manualmente para o coletor.' 'warn'
    return $false
  }
  $env:Path = "$(Split-Path $adbPath -Parent);" + $env:Path
  $oldEa = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $devicesOut = & $adbPath devices 2>&1
  } finally {
    $ErrorActionPreference = $oldEa
  }
  $devices = $devicesOut | Select-String -Pattern "`tdevice$"
  if (-not $devices) {
    Sil-Log 'Nenhum coletor conectado no ADB.' 'warn'
    return $false
  }
  $serial = (($devices | Select-Object -First 1).ToString() -split "`t")[0].Trim()
  Sil-Log "Coletor ADB: $serial" 'ok'
  if ($dryRun) { Sil-Log "DryRun: adb install -r $apkPath" 'warn'; return $true }
  $instCode = Sil-InvokeNative -FilePath $adbPath -ArgumentList @('-s', $serial, 'install', '-r', $apkPath) -LogOutput
  if ($instCode -ne 0) { throw "adb install falhou (codigo $instCode)" }
  $null = Sil-InvokeNative -FilePath $adbPath -ArgumentList @(
    '-s', $serial, 'shell', 'monkey', '-p', 'br.com.rhm.rhm_coletor',
    '-c', 'android.intent.category.LAUNCHER', '1'
  )
  Sil-Log 'APK instalado e app iniciado' 'ok'
  return $true
}

function Sil-SaveConfig([hashtable]$cfg, [string]$path) {
  $obj = [ordered]@{
    clienteNome        = $cfg.clienteNome
    repoRoot           = $cfg.repoRoot
    apiHost            = $cfg.apiHost
    apiPort            = $cfg.apiPort
    apiPublicIp        = $cfg.apiPublicIp
    winthorProvider    = $cfg.winthorProvider
    oracleConn         = $cfg.oracleConn
    oracleUser         = $cfg.oracleUser
    oraclePassword     = $cfg.oraclePassword
    flutterBin         = $cfg.flutterBin
    buildDir           = $cfg.buildDir
    apkRelease         = $cfg.apkRelease
    abrirFirewall      = $cfg.abrirFirewall
    iniciarApi         = $cfg.iniciarApi
    criarAtalhoStartup = $cfg.criarAtalhoStartup
    instalarNoColetor  = $cfg.instalarNoColetor
  }
  $utf8Bom = New-Object System.Text.UTF8Encoding $true
  [System.IO.File]::WriteAllText($path, (($obj | ConvertTo-Json -Depth 4) + "`r`n"), $utf8Bom)
  Sil-Log "Config salva: $path" 'ok'
}

function Sil-LoadConfig([string]$path) {
  $raw = Get-Content -Raw -Path $path -Encoding UTF8 | ConvertFrom-Json
  $repo = if ($raw.repoRoot) { $raw.repoRoot } else { $script:SilDefaultRepoRoot }
  if (-not [IO.Path]::IsPathRooted($repo)) { $repo = Join-Path $script:SilScriptDir $repo }
  return @{
    clienteNome        = $(if ($raw.clienteNome) { $raw.clienteNome } else { 'Cliente' })
    repoRoot           = (Resolve-Path $repo).Path
    apiHost            = $(if ($raw.apiHost) { $raw.apiHost } else { '0.0.0.0' })
    apiPort            = $(if ($raw.apiPort) { [int]$raw.apiPort } else { 8080 })
    apiPublicIp        = "$($raw.apiPublicIp)"
    winthorProvider    = $(if ($raw.winthorProvider) { $raw.winthorProvider } else { 'mock' })
    oracleConn         = "$($raw.oracleConn)"
    oracleUser         = "$($raw.oracleUser)"
    oraclePassword     = "$($raw.oraclePassword)"
    flutterBin         = $(if ($raw.flutterBin) { $raw.flutterBin } else { 'D:\flutter\bin' })
    buildDir           = $(if ($raw.buildDir) { $raw.buildDir } else { 'D:\sil_build' })
    apkRelease         = [bool]($(if ($null -ne $raw.apkRelease) { $raw.apkRelease } else { $true }))
    abrirFirewall      = [bool]($(if ($null -ne $raw.abrirFirewall) { $raw.abrirFirewall } else { $true }))
    iniciarApi         = [bool]($(if ($null -ne $raw.iniciarApi) { $raw.iniciarApi } else { $true }))
    criarAtalhoStartup = [bool]($(if ($null -ne $raw.criarAtalhoStartup) { $raw.criarAtalhoStartup } else { $false }))
    instalarNoColetor  = [bool]($(if ($null -ne $raw.instalarNoColetor) { $raw.instalarNoColetor } else { $false }))
  }
}

function Sil-DefaultConfig {
  $ips = @(Sil-GetLanIPv4)
  $flutter = Sil-FindFlutterBin 'D:\flutter\bin'
  return @{
    clienteNome        = 'Cliente'
    repoRoot           = $script:SilDefaultRepoRoot
    apiHost            = '0.0.0.0'
    apiPort            = 8080
    apiPublicIp        = $(if ($ips.Count) { $ips[0] } else { '192.168.0.10' })
    winthorProvider    = 'mock'
    oracleConn         = ''
    oracleUser         = ''
    oraclePassword     = ''
    flutterBin         = $(if ($flutter) { $flutter } else { 'D:\flutter\bin' })
    buildDir           = 'D:\sil_build'
    apkRelease         = $true
    abrirFirewall      = $true
    iniciarApi         = $true
    criarAtalhoStartup = $false
    instalarNoColetor  = $false
  }
}

function Sil-RunDeploy {
  param(
    [hashtable]$Cfg,
    [bool]$DoApi = $true,
    [bool]$DoApk = $true,
    [bool]$DryRun = $false,
    [bool]$AllowPrereqDownload = $false
  )

  if (-not $Cfg.apiPublicIp) {
    $ips = @(Sil-GetLanIPv4)
    $Cfg.apiPublicIp = if ($ips.Count) { $ips[0] } else { '127.0.0.1' }
  }

  $safe = ($Cfg.clienteNome -replace '[^\w\-]', '_')
  $cfgOut = Join-Path $script:SilScriptDir "cliente-$safe.json"
  $startScript = Join-Path $script:SilScriptDir "Iniciar-API-$safe.ps1"
  $apkPath = $null
  $result = @{ ConfigPath = $cfgOut; StartScript = $startScript; ApkPath = $null; FlutterBin = $null; Ok = $false }

  try {
    Sil-SetStep 'prereq' 'running' 'Verificando pre-requisitos'
    Sil-Log 'Pre-requisitos' 'step'
    $needAdb = [bool]$Cfg.instalarNoColetor
    $tools = Sil-EnsurePrerequisites -Cfg $Cfg -NeedApk:$DoApk -NeedAdb:$needAdb `
      -AllowDownload:$AllowPrereqDownload -DryRun:$DryRun
    $result.FlutterBin = $Cfg.flutterBin
    Sil-Log "Flutter/Dart: $($Cfg.flutterBin)" 'ok'
    Sil-Log "Repo: $($Cfg.repoRoot)" 'ok'
    Sil-Log "API: http://$($Cfg.apiPublicIp):$($Cfg.apiPort) ($($Cfg.winthorProvider))" 'ok'
    Sil-SetStep 'prereq' 'done'

    Sil-SetStep 'config' 'running' 'Salvando configuracao do cliente'
    if (-not $DryRun) { Sil-SaveConfig -cfg $Cfg -path $cfgOut } else { Sil-Log "DryRun: $cfgOut" 'warn' }
    Sil-SetStep 'config' 'done'

    if ($DoApi) {
      Sil-SetStep 'deps' 'running' 'dart pub get'
      Sil-ApiDeps -repoRoot $Cfg.repoRoot -tools $tools -dryRun:$DryRun
      Sil-SetStep 'deps' 'done'

      Sil-SetStep 'script' 'running' 'Gerando Iniciar-API'
      Sil-WriteApiStartScript -cfg $Cfg -outPath $startScript -dryRun:$DryRun
      Sil-SetStep 'script' 'done'

      if ($Cfg.abrirFirewall) {
        Sil-SetStep 'firewall' 'running' "Porta $($Cfg.apiPort)"
        Sil-EnsureFirewall -port $Cfg.apiPort -dryRun:$DryRun
        Sil-SetStep 'firewall' 'done'
      } else {
        Sil-SetStep 'firewall' 'skipped' 'Ignorado pelo usuario'
      }

      if ($Cfg.criarAtalhoStartup) {
        Sil-SetStep 'startup' 'running'
        Sil-StartupShortcut -startScript $startScript -clienteNome $safe -dryRun:$DryRun
        Sil-SetStep 'startup' 'done'
      } else {
        Sil-SetStep 'startup' 'skipped'
      }

      if ($Cfg.iniciarApi) {
        Sil-SetStep 'api' 'running' 'Iniciando servidor'
        Sil-StartApi -startScript $startScript -port $Cfg.apiPort -dryRun:$DryRun
        Start-Sleep -Seconds 2
        Sil-SetStep 'api' 'done'

        Sil-SetStep 'health' 'running' 'GET /health'
        $h1 = Sil-Health -ip '127.0.0.1' -port $Cfg.apiPort
        $h2 = Sil-Health -ip $Cfg.apiPublicIp -port $Cfg.apiPort
        if ($h1 -or $h2 -or $DryRun) { Sil-SetStep 'health' 'done' } else { Sil-SetStep 'health' 'error' 'API nao respondeu' }
      } else {
        Sil-SetStep 'api' 'skipped'
        Sil-SetStep 'health' 'skipped'
      }
    } else {
      foreach ($id in @('deps','script','firewall','startup','api','health')) { Sil-SetStep $id 'skipped' }
    }

    if ($DoApk) {
      Sil-SetStep 'apk' 'running' 'Compilando (pode levar alguns minutos)'
      $apkPath = Sil-BuildApk -cfg $Cfg -tools $tools -dryRun:$DryRun
      $result.ApkPath = $apkPath
      Sil-SetStep 'apk' 'done' $(if ($apkPath) { $apkPath } else { '' })

      if ($Cfg.instalarNoColetor) {
        Sil-SetStep 'adb' 'running' 'adb install'
        if ($apkPath) {
          $okAdb = Sil-InstallAdb -apkPath $apkPath -dryRun:$DryRun
          if ($okAdb) { Sil-SetStep 'adb' 'done' } else { Sil-SetStep 'adb' 'error' 'Sem dispositivo ou adb' }
        } else {
          Sil-SetStep 'adb' 'skipped'
        }
      } else {
        Sil-SetStep 'adb' 'skipped'
      }
    } else {
      Sil-SetStep 'apk' 'skipped'
      Sil-SetStep 'adb' 'skipped'
    }

    Sil-SetStep 'fim' 'done' 'Deploy concluido'
    Sil-Log 'Deploy S.I.L. concluido' 'ok'
    $result.Ok = $true
    return $result
  } catch {
    Sil-Log $_.Exception.Message 'err'
    Sil-SetStep 'fim' 'error' $_.Exception.Message
    throw
  }
}

$script:SilDeploySteps = @(
  @{ Id = 'prereq';   Label = '1. Verificar / baixar Flutter, JDK e Android SDK' }
  @{ Id = 'config';   Label = '2. Salvar configuracao do cliente' }
  @{ Id = 'deps';     Label = '3. Instalar dependencias da API' }
  @{ Id = 'script';   Label = '4. Gerar script de inicializacao da API' }
  @{ Id = 'firewall'; Label = '5. Liberar porta no firewall do Windows' }
  @{ Id = 'startup';  Label = '6. Atalho para iniciar API no logon (opcional)' }
  @{ Id = 'api';      Label = '7. Iniciar a API S.I.L.' }
  @{ Id = 'health';   Label = '8. Testar saude da API (HTTP /health)' }
  @{ Id = 'apk';      Label = '9. Compilar o aplicativo Android (APK)' }
  @{ Id = 'adb';      Label = '10. Instalar APK no coletor via USB/ADB (opcional)' }
  @{ Id = 'fim';      Label = '11. Finalizacao' }
)
