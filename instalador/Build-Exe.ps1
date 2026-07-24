#Requires -Version 5.1
<#
.SYNOPSIS
  Compila SIL-Instalador.exe (launcher WinForms + UAC admin).

.EXAMPLE
  .\Build-Exe.ps1
#>
[CmdletBinding()]
param(
  [string]$OutName = 'SIL-Instalador.exe'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcDir = Join-Path $root 'launcher'
$cs = Join-Path $srcDir 'SilInstalador.cs'
$manifest = Join-Path $srcDir 'app.manifest'
$out = Join-Path $root $OutName

$cscCandidates = @(
  (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'),
  (Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe')
)
$csc = $cscCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $csc) { throw 'csc.exe (.NET Framework 4.x) nao encontrado.' }

if (-not (Test-Path $cs)) { throw "Fonte nao encontrada: $cs" }
if (-not (Test-Path $manifest)) { throw "Manifest nao encontrado: $manifest" }

Write-Host "Compilando com: $csc" -ForegroundColor Cyan
Write-Host "Saida: $out"

$args = @(
  '/nologo',
  '/target:winexe',
  '/platform:anycpu',
  '/optimize+',
  "/out:$out",
  '/reference:System.Windows.Forms.dll',
  '/reference:System.Drawing.dll',
  "/win32manifest:$manifest",
  $cs
)

& $csc @args
if ($LASTEXITCODE -ne 0) { throw "csc falhou com codigo $LASTEXITCODE" }
if (-not (Test-Path $out)) { throw "EXE nao gerado: $out" }

$info = Get-Item $out
Write-Host ("OK  {0} ({1:N1} KB)" -f $info.FullName, ($info.Length / 1KB)) -ForegroundColor Green
Write-Host 'Execute como administrador (UAC). Mantenha o .exe na pasta instalador\ junto aos .ps1.'
