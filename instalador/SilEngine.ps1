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
    & $tools.Dart pub get
    if ($LASTEXITCODE -ne 0) { throw 'dart pub get falhou' }
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
    & $tools.Flutter pub get
    if ($cfg.apkRelease) {
      & $tools.Flutter build apk --release --dart-define="SIL_API_BASE_URL=$baseUrl"
    } else {
      & $tools.Flutter build apk --debug --dart-define="SIL_API_BASE_URL=$baseUrl"
    }
    if ($LASTEXITCODE -ne 0) { throw 'flutter build apk falhou' }
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
  $adb = Get-Command adb -ErrorAction SilentlyContinue
  if (-not $adb) {
    $sdk = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
    if (Test-Path $sdk) {
      $env:Path = "$(Split-Path $sdk -Parent);" + $env:Path
      $adb = Get-Command adb -ErrorAction SilentlyContinue
    }
  }
  if (-not $adb) {
    Sil-Log 'adb nao encontrado - copie o APK manualmente para o coletor.' 'warn'
    return $false
  }
  $devices = adb devices | Select-String -Pattern "`tdevice$"
  if (-not $devices) {
    Sil-Log 'Nenhum coletor conectado no ADB.' 'warn'
    return $false
  }
  $serial = (($devices | Select-Object -First 1).ToString() -split "`t")[0].Trim()
  Sil-Log "Coletor ADB: $serial" 'ok'
  if ($dryRun) { Sil-Log "DryRun: adb install -r $apkPath" 'warn'; return $true }
  adb -s $serial install -r $apkPath
  if ($LASTEXITCODE -ne 0) { throw 'adb install falhou' }
  adb -s $serial shell monkey -p br.com.rhm.rhm_coletor -c android.intent.category.LAUNCHER 1 | Out-Null
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
    [bool]$DryRun = $false
  )

  if (-not $Cfg.apiPublicIp) {
    $ips = @(Sil-GetLanIPv4)
    $Cfg.apiPublicIp = if ($ips.Count) { $ips[0] } else { '127.0.0.1' }
  }

  $safe = ($Cfg.clienteNome -replace '[^\w\-]', '_')
  $cfgOut = Join-Path $script:SilScriptDir "cliente-$safe.json"
  $startScript = Join-Path $script:SilScriptDir "Iniciar-API-$safe.ps1"
  $apkPath = $null
  $result = @{ ConfigPath = $cfgOut; StartScript = $startScript; ApkPath = $null; Ok = $false }

  try {
    Sil-SetStep 'prereq' 'running' 'Verificando Flutter/Dart'
    Sil-Log 'Pre-requisitos' 'step'
    $tools = Sil-EnsureFlutter $Cfg.flutterBin
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
  @{ Id = 'prereq';   Label = '1. Verificar Flutter / Dart no computador' }
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
