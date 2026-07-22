#Requires -Version 5.1
<#
.SYNOPSIS
  Instalador CLI do S.I.L. (usa SilEngine.ps1).

.EXAMPLE
  .\Instalar-SIL.ps1
  .\Instalar-SIL.ps1 -Config .\cliente-RHM.json -SomenteApk
  .\Abrir-Instalador.ps1   # interface visual (recomendado no cliente)
#>
[CmdletBinding()]
param(
  [string]$Config,
  [switch]$SomenteApi,
  [switch]$SomenteApk,
  [switch]$InstalarNoColetor,
  [switch]$DryRun,
  [switch]$Ui
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if ($Ui) {
  if ($Config) {
    & "$ScriptDir\Abrir-Instalador.ps1" -Config $Config
  } else {
    & "$ScriptDir\Abrir-Instalador.ps1"
  }
  exit $LASTEXITCODE
}

. "$ScriptDir\SilEngine.ps1"

function Read-Default([string]$prompt, [string]$default) {
  $suffix = if ($default) { " [$default]" } else { '' }
  $v = Read-Host "$prompt$suffix"
  if ([string]::IsNullOrWhiteSpace($v)) { return $default }
  return $v.Trim()
}

function Read-YesNo([string]$prompt, [bool]$default = $true) {
  $d = if ($default) { 'S' } else { 'N' }
  $v = Read-Host "$prompt (S/N) [$d]"
  if ([string]::IsNullOrWhiteSpace($v)) { return $default }
  return $v.Trim().ToUpperInvariant().StartsWith('S')
}

function New-ConfigFromWizard {
  Write-Host ''
  Write-Host '========================================' -ForegroundColor Cyan
  Write-Host '  S.I.L. - Instalador (modo texto)' -ForegroundColor Cyan
  Write-Host '  Para tela visual: .\Abrir-Instalador.ps1' -ForegroundColor DarkGray
  Write-Host '========================================' -ForegroundColor Cyan

  $base = Sil-DefaultConfig
  $clienteNome = Read-Default 'Nome do cliente' $base.clienteNome
  $repoRoot = Read-Default 'Pasta do repositorio sil' $base.repoRoot
  $ips = @(Sil-GetLanIPv4)
  if ($ips.Count -gt 0) {
    Write-Host 'IPs detectados:' -ForegroundColor DarkGray
    for ($i = 0; $i -lt $ips.Count; $i++) { Write-Host ("  [{0}] {1}" -f ($i + 1), $ips[$i]) }
  }
  $apiPublicIp = Read-Default 'IP da API para os coletores' $base.apiPublicIp
  $apiPort = [int](Read-Default 'Porta' "$($base.apiPort)")
  $flutterBin = Read-Default 'Flutter/Dart bin' $base.flutterBin
  $buildDir = Read-Default 'Build dir (sem espaco)' $base.buildDir
  $winthor = Read-Default 'Provedor (mock/oracle)' $base.winthorProvider
  $oracleConn = ''; $oracleUser = ''; $oraclePassword = ''
  if ($winthor -eq 'oracle') {
    $oracleConn = Read-Default 'SIL_ORACLE_CONN' 'host:1521/SERVICE'
    $oracleUser = Read-Default 'SIL_ORACLE_USER' ''
    $oraclePassword = Read-Default 'SIL_ORACLE_PASSWORD' ''
  }
  return @{
    clienteNome        = $clienteNome
    repoRoot           = (Resolve-Path $repoRoot).Path
    apiHost            = '0.0.0.0'
    apiPort            = $apiPort
    apiPublicIp        = $apiPublicIp
    winthorProvider    = $winthor.ToLowerInvariant()
    oracleConn         = $oracleConn
    oracleUser         = $oracleUser
    oraclePassword     = $oraclePassword
    flutterBin         = $flutterBin
    buildDir           = $buildDir
    apkRelease         = (Read-YesNo 'APK release' $true)
    abrirFirewall      = (Read-YesNo 'Liberar firewall' $true)
    iniciarApi         = (Read-YesNo 'Iniciar API agora' $true)
    criarAtalhoStartup = (Read-YesNo 'Atalho no logon' $false)
    instalarNoColetor  = (Read-YesNo 'Instalar no coletor via ADB' $false)
  }
}

try {
  if ($Config) {
    $cfg = Sil-LoadConfig $Config
  } else {
    $cfg = New-ConfigFromWizard
  }
  if ($InstalarNoColetor) { $cfg.instalarNoColetor = $true }

  $doApi = -not $SomenteApk
  $doApk = -not $SomenteApi
  $allowDownload = $false
  $probe = Sil-ProbePrerequisites -Cfg $cfg -NeedApk:$doApk -NeedAdb:([bool]$cfg.instalarNoColetor)
  if (-not $probe.Ok) {
    Write-Host ''
    Write-Host "Pre-requisitos ausentes: $($probe.Missing -join ', ')" -ForegroundColor Yellow
    Write-Host 'O instalador pode baixar Flutter (stable), JDK 17 e Android SDK automaticamente.' -ForegroundColor DarkGray
    Write-Host 'Isso pode consumir varios GB e alguns minutos de internet.' -ForegroundColor DarkGray
    if (Read-YesNo 'Baixar e instalar os pre-requisitos agora' $true) {
      $allowDownload = $true
    } else {
      throw 'Instalacao cancelada: pre-requisitos ausentes e download nao autorizado.'
    }
  } elseif ($probe.FlutterBin) {
    $cfg.flutterBin = $probe.FlutterBin
  }

  $res = Sil-RunDeploy -Cfg $cfg -DoApi:$doApi -DoApk:$doApk -DryRun:$DryRun -AllowPrereqDownload:$allowDownload

  Write-Host ''
  Write-Host 'Concluido.' -ForegroundColor Green
  Write-Host "Config: $($res.ConfigPath)"
  Write-Host "API:    $($res.StartScript)"
  if ($res.ApkPath) { Write-Host "APK:    $($res.ApkPath)" }
  Write-Host "URL:    http://$($cfg.apiPublicIp):$($cfg.apiPort)"
  exit 0
} catch {
  Write-Host $_.Exception.Message -ForegroundColor Red
  exit 1
}
