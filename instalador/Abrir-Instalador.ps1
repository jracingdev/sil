#Requires -Version 5.1
<#
.SYNOPSIS
  Interface visual do instalador S.I.L.

.DESCRIPTION
  Checklist ao vivo + log. O trabalho pesado roda em Runspace separado
  (ThreadPool do .NET quebrava as funcoes PowerShell).

.EXAMPLE
  .\Abrir-Instalador.ps1
#>
param([string]$Config)

$ErrorActionPreference = 'Stop'
$script:UiErrorLog = Join-Path $PSScriptRoot 'instalador_erro.txt'

try {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  . "$PSScriptRoot\SilEngine.ps1"
  [System.Windows.Forms.Application]::EnableVisualStyles()

  # Placeholder (cue banner) nos TextBox - .NET Framework nao tem PlaceholderText nativo
  if (-not ('SilCueBanner' -as [type])) {
    Add-Type -Namespace Sil -Name CueBanner -MemberDefinition @"
      [System.Runtime.InteropServices.DllImport("user32.dll", CharSet=System.Runtime.InteropServices.CharSet.Unicode)]
      public static extern System.IntPtr SendMessage(System.IntPtr hWnd, int msg, System.IntPtr wParam, string lParam);
      public const int EM_SETCUEBANNER = 0x1501;
"@
  }
} catch {
  $_ | Out-File -FilePath $script:UiErrorLog -Encoding utf8
  [System.Windows.Forms.MessageBox]::Show(
    "Falha ao iniciar o instalador.`r`n`r`n$($_.Exception.Message)`r`n`r`nDetalhes: $script:UiErrorLog",
    'S.I.L.',
    'OK',
    'Error'
  ) | Out-Null
  exit 1
}

$script:StepLabels = @{}
$script:StepStatus = @{}
$script:IsRunning = $false
$script:LastApk = $null
$script:DeployPs = $null
$script:DeployHandle = $null
$script:DeployRunspace = $null
$script:Sync = $null
$script:LogCursor = 0
$script:ProgressDisplay = 0
$script:ProgressTarget = 0

function Add-LogLine([string]$msg, [string]$level) {
  if (-not $txtLog -or $txtLog.IsDisposed) { return }
  $ts = Get-Date -Format 'HH:mm:ss'
  $prefix = switch ($level) {
    'ok'   { '[OK]   ' }
    'warn' { '[AVISO]' }
    'err'  { '[ERRO] ' }
    'step' { '[PASSO]' }
    default { '[INFO] ' }
  }
  $txtLog.AppendText("$ts $prefix $msg`r`n")
  $txtLog.SelectionStart = $txtLog.Text.Length
  $txtLog.ScrollToCaret()
}

function Update-ProgressBar {
  param([switch]$Immediate)

  $total = [math]::Max(1, $script:SilDeploySteps.Count)
  $finished = 0
  $running = $false
  foreach ($s in $script:SilDeploySteps) {
    $st = $script:StepStatus[$s.Id]
    if (-not $st) { $st = 'pending' }
    if ($st -in @('done', 'skipped', 'error')) { $finished++ }
    if ($st -eq 'running') { $running = $true }
  }

  # Passos concluidos + metade do passo em andamento = sensacao de progresso continuo
  $pct = [int][math]::Round((($finished + $(if ($running) { 0.45 } else { 0 })) / $total) * 100)
  if ($pct -gt 100) { $pct = 100 }
  if ($script:IsRunning -and $pct -ge 100 -and $finished -lt $total) { $pct = 99 }
  if (-not $script:IsRunning -and $finished -eq 0) { $pct = 0 }

  $script:ProgressTarget = $pct
  if ($Immediate) {
    $script:ProgressDisplay = $pct
  } else {
    # animacao suave em direcao ao alvo
    if ($script:ProgressDisplay -lt $script:ProgressTarget) {
      $step = [math]::Max(1, [math]::Ceiling(($script:ProgressTarget - $script:ProgressDisplay) / 4))
      $script:ProgressDisplay = [math]::Min($script:ProgressTarget, $script:ProgressDisplay + $step)
    } elseif ($script:ProgressDisplay -gt $script:ProgressTarget) {
      $script:ProgressDisplay = $script:ProgressTarget
    }
  }

  if ($progress -and -not $progress.IsDisposed) {
    $progress.Style = 'Continuous'
    $progress.Minimum = 0
    $progress.Maximum = 100
    $progress.Value = [math]::Max(0, [math]::Min(100, [int]$script:ProgressDisplay))
  }
  if ($lblPercent -and -not $lblPercent.IsDisposed) {
    $lblPercent.Text = "{0}%" -f [int]$script:ProgressDisplay
    if ($script:IsRunning) {
      $lblPercent.ForeColor = [Drawing.Color]::FromArgb(16, 80, 180)
    } elseif ($script:ProgressDisplay -ge 100) {
      $lblPercent.ForeColor = [Drawing.Color]::FromArgb(20, 120, 60)
    } else {
      $lblPercent.ForeColor = [Drawing.Color]::FromArgb(60, 60, 60)
    }
  }
}

function Set-StepUi([string]$id, [string]$status, [string]$detail) {
  if (-not $script:StepLabels.ContainsKey($id)) { return }
  $script:StepStatus[$id] = $status
  $lbl = $script:StepLabels[$id]
  $base = [string]$lbl.Tag
  $icon = switch ($status) {
    'pending' { '[ ]' }
    'running' { '[>]' }
    'done'    { '[OK]' }
    'error'   { '[X]' }
    'skipped' { '[-]' }
    default   { '[ ]' }
  }
  $color = switch ($status) {
    'pending' { [Drawing.Color]::FromArgb(90, 90, 90) }
    'running' { [Drawing.Color]::FromArgb(16, 80, 180) }
    'done'    { [Drawing.Color]::FromArgb(20, 120, 60) }
    'error'   { [Drawing.Color]::FromArgb(180, 40, 40) }
    'skipped' { [Drawing.Color]::FromArgb(130, 130, 130) }
    default   { [Drawing.Color]::Black }
  }
  $extra = if ($detail) { " - $detail" } else { '' }
  $lbl.Text = "$icon  $base$extra"
  $lbl.ForeColor = $color
  if ($status -eq 'running') {
    $lblStatus.Text = "Em andamento: $base"
    $lblStatus.ForeColor = [Drawing.Color]::FromArgb(16, 80, 180)
  }
  Update-ProgressBar
}

function Reset-Steps {
  foreach ($s in $script:SilDeploySteps) {
    $script:StepStatus[$s.Id] = 'pending'
    Set-StepUi $s.Id 'pending' ''
  }
  $script:ProgressDisplay = 0
  $script:ProgressTarget = 0
  Update-ProgressBar -Immediate
  $lblStatus.Text = 'Pronto. Revise os dados e clique em Iniciar instalacao.'
  $lblStatus.ForeColor = [Drawing.Color]::FromArgb(40, 40, 40)
}

function Get-FormConfig {
  $provider = if ($cmbWinthor.SelectedIndex -eq 1) { 'oracle' } else { 'mock' }
  return @{
    clienteNome        = $txtCliente.Text.Trim()
    repoRoot           = $txtRepo.Text.Trim()
    apiHost            = '0.0.0.0'
    apiPort            = [int]$numPort.Value
    apiPublicIp        = $txtIp.Text.Trim()
    winthorProvider    = $provider
    oracleConn         = $txtOracleConn.Text.Trim()
    oracleUser         = $txtOracleUser.Text.Trim()
    oraclePassword     = $txtOraclePass.Text
    flutterBin         = $txtFlutter.Text.Trim()
    buildDir           = $txtBuild.Text.Trim()
    apkRelease         = $chkRelease.Checked
    abrirFirewall      = $chkFirewall.Checked
    iniciarApi         = $chkStartApi.Checked
    criarAtalhoStartup = $chkStartup.Checked
    instalarNoColetor  = $chkAdb.Checked
  }
}

function Set-FormConfig([hashtable]$cfg) {
  $txtCliente.Text = $cfg.clienteNome
  $txtRepo.Text = $cfg.repoRoot
  $txtIp.Text = $cfg.apiPublicIp
  $numPort.Value = [decimal]$cfg.apiPort
  $txtFlutter.Text = $cfg.flutterBin
  $txtBuild.Text = $cfg.buildDir
  $cmbWinthor.SelectedIndex = $(if ($cfg.winthorProvider -eq 'oracle') { 1 } else { 0 })
  $txtOracleConn.Text = $cfg.oracleConn
  $txtOracleUser.Text = $cfg.oracleUser
  $txtOraclePass.Text = $cfg.oraclePassword
  $chkRelease.Checked = [bool]$cfg.apkRelease
  $chkFirewall.Checked = [bool]$cfg.abrirFirewall
  $chkStartApi.Checked = [bool]$cfg.iniciarApi
  $chkStartup.Checked = [bool]$cfg.criarAtalhoStartup
  $chkAdb.Checked = [bool]$cfg.instalarNoColetor
  Update-OracleEnabled
}

function Update-OracleEnabled {
  $en = $cmbWinthor.SelectedIndex -eq 1
  $txtOracleConn.Enabled = $en
  $txtOracleUser.Enabled = $en
  $txtOraclePass.Enabled = $en
}

function Set-UiBusy([bool]$busy) {
  $script:IsRunning = $busy
  $btnStart.Enabled = -not $busy
  $btnDry.Enabled = -not $busy
  $grpConfig.Enabled = -not $busy
  if (-not $busy) {
    # deixa o timer animar ate o percentual final; para apos sync
  }
  Update-ProgressBar
}

function Clear-DeployRunspace {
  try {
    if ($script:DeployPs -and $script:DeployHandle) {
      if ($script:DeployHandle.IsCompleted) {
        try { $script:DeployPs.EndInvoke($script:DeployHandle) | Out-Null } catch {}
      } else {
        try { $script:DeployPs.Stop() } catch {}
      }
    }
  } catch {}
  try { if ($script:DeployPs) { $script:DeployPs.Dispose() } } catch {}
  try { if ($script:DeployRunspace) { $script:DeployRunspace.Close(); $script:DeployRunspace.Dispose() } } catch {}
  $script:DeployPs = $null
  $script:DeployHandle = $null
  $script:DeployRunspace = $null
}

function Start-DeployJob([bool]$dry) {
  if ($script:IsRunning) { return }
  if (-not $txtCliente.Text.Trim()) {
    [Windows.Forms.MessageBox]::Show('Informe o nome do cliente.', 'S.I.L.', 'OK', 'Warning') | Out-Null
    return
  }
  if (-not $txtIp.Text.Trim()) {
    [Windows.Forms.MessageBox]::Show('Informe o IP da API.', 'S.I.L.', 'OK', 'Warning') | Out-Null
    return
  }
  if (-not (Test-Path $txtRepo.Text.Trim())) {
    [Windows.Forms.MessageBox]::Show("Pasta do projeto nao encontrada:`r`n$($txtRepo.Text)", 'S.I.L.', 'OK', 'Warning') | Out-Null
    return
  }

  $adminHint = ''
  if ($chkFirewall.Checked -and -not (Sil-IsAdmin)) {
    $adminHint = "`r`n`r`nObs: sem Administrador o firewall pode falhar (o restante segue)."
  }
  $modo = if ($dry) { 'SIMULACAO' } else { 'INSTALACAO REAL' }
  $msg = "Sera configurado o S.I.L. neste computador.`r`n`r`nCliente: $($txtCliente.Text)`r`nAPI: http://$($txtIp.Text):$($numPort.Value)`r`nModo: $modo$adminHint`r`n`r`nDeseja continuar?"
  if ([Windows.Forms.MessageBox]::Show($msg, 'S.I.L. - Confirmacao', 'YesNo', 'Question') -ne 'Yes') { return }

  Clear-DeployRunspace
  Reset-Steps
  $txtLog.Clear()
  Set-UiBusy $true
  $cfg = Get-FormConfig
  $script:LogCursor = 0

  $sync = [hashtable]::Synchronized(@{
    Logs   = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
    Steps  = [hashtable]::Synchronized(@{})
    Done   = $false
    Error  = $null
    Result = $null
    Dry    = $dry
  })
  $script:Sync = $sync

  $enginePath = Join-Path $PSScriptRoot 'SilEngine.ps1'
  $rs = [runspacefactory]::CreateRunspace()
  $rs.ApartmentState = 'MTA'
  $rs.ThreadOptions = 'ReuseThread'
  $rs.Open()
  $ps = [powershell]::Create()
  $ps.Runspace = $rs

  [void]$ps.AddScript({
    param($EnginePath, $Cfg, $DryRunFlag, $Sync)
    $ErrorActionPreference = 'Stop'
    . $EnginePath
    $script:SilLogHandler = {
      param($Message, $Level)
      [void]$Sync.Logs.Add(@{ M = [string]$Message; L = [string]$Level; T = (Get-Date) })
    }
    $script:SilStepHandler = {
      param($Id, $Status, $Detail)
      $Sync.Steps[[string]$Id] = @{ S = [string]$Status; D = [string]$Detail }
    }
    try {
      $Sync.Result = Sil-RunDeploy -Cfg $Cfg -DoApi $true -DoApk $true -DryRun:$DryRunFlag
      $Sync.Done = $true
    } catch {
      $Sync.Error = $_.Exception.Message
      $Sync.Steps['fim'] = @{ S = 'error'; D = $_.Exception.Message }
      [void]$Sync.Logs.Add(@{ M = $_.Exception.Message; L = 'err'; T = (Get-Date) })
      $Sync.Done = $true
    }
  }).AddArgument($enginePath).AddArgument($cfg).AddArgument($dry).AddArgument($sync)

  $script:DeployRunspace = $rs
  $script:DeployPs = $ps
  $script:DeployHandle = $ps.BeginInvoke()
  $timer.Start()
  Add-LogLine 'Execucao iniciada em segundo plano...' 'info'
}

function Update-FromSync {
  $sync = $script:Sync
  if (-not $sync) { return }

  while ($script:LogCursor -lt $sync.Logs.Count) {
    $item = $sync.Logs[$script:LogCursor]
    Add-LogLine $item.M $item.L
    $script:LogCursor++
  }

  foreach ($key in @($sync.Steps.Keys)) {
    $st = $sync.Steps[$key]
    Set-StepUi $key $st.S $st.D
  }

  # anima a barra mesmo entre atualizacoes de passo
  Update-ProgressBar

  if (-not $sync.Done) { return }

  # garante 100% ao terminar com sucesso
  if (-not $sync.Error) {
    $script:ProgressTarget = 100
    Update-ProgressBar -Immediate
  }

  Set-UiBusy $false
  $timer.Stop()

  if ($sync.Error) {
    $lblStatus.Text = "Falhou: $($sync.Error)"
    $lblStatus.ForeColor = [Drawing.Color]::FromArgb(180, 40, 40)
    [Windows.Forms.MessageBox]::Show($sync.Error, 'S.I.L. - Erro', 'OK', 'Error') | Out-Null
  } else {
    if ($sync.Result -and $sync.Result.ApkPath) { $script:LastApk = $sync.Result.ApkPath }
    $lblStatus.Text = if ($sync.Dry) { 'Simulacao concluida.' } else { 'Instalacao concluida com sucesso.' }
    $lblStatus.ForeColor = [Drawing.Color]::FromArgb(20, 120, 60)
    $body = if ($sync.Dry) {
      'Simulacao concluida. Revise o log e a lista de procedimentos.'
    } else {
      "Concluido.`r`n`r`nConfig: $($sync.Result.ConfigPath)`r`nAPI: $($sync.Result.StartScript)`r`nAPK: $($sync.Result.ApkPath)"
    }
    [Windows.Forms.MessageBox]::Show($body, 'S.I.L.', 'OK', 'Information') | Out-Null
  }
  Clear-DeployRunspace
}

# ---- UI ----
$form = New-Object Windows.Forms.Form
$form.Text = 'S.I.L. - Instalador visual no cliente'
$form.Size = New-Object Drawing.Size(980, 720)
$form.StartPosition = 'CenterScreen'
$form.MinimumSize = New-Object Drawing.Size(900, 640)
$form.BackColor = [Drawing.Color]::FromArgb(245, 247, 250)
$form.Font = New-Object Drawing.Font('Segoe UI', 9)

$timer = New-Object Windows.Forms.Timer
$timer.Interval = 250
$timer.Add_Tick({ Update-FromSync })

$header = New-Object Windows.Forms.Panel
$header.Dock = 'Top'
$header.Height = 72
$header.BackColor = [Drawing.Color]::FromArgb(16, 43, 78)
$form.Controls.Add($header)

$lblTitle = New-Object Windows.Forms.Label
$lblTitle.Text = 'S.I.L. - Sistema Integrado Logistico'
$lblTitle.ForeColor = [Drawing.Color]::White
$lblTitle.Font = New-Object Drawing.Font('Segoe UI Semibold', 14)
$lblTitle.AutoSize = $true
$lblTitle.Location = New-Object Drawing.Point(20, 12)
$header.Controls.Add($lblTitle)

$lblSub = New-Object Windows.Forms.Label
$lblSub.Text = 'Instalacao acompanhada passo a passo - API, rede e aplicativo do coletor'
$lblSub.ForeColor = [Drawing.Color]::FromArgb(200, 210, 230)
$lblSub.AutoSize = $true
$lblSub.Location = New-Object Drawing.Point(22, 42)
$header.Controls.Add($lblSub)

$lblStatus = New-Object Windows.Forms.Label
$lblStatus.Dock = 'Bottom'
$lblStatus.Height = 26
$lblStatus.BackColor = [Drawing.Color]::FromArgb(230, 235, 240)
$lblStatus.TextAlign = 'MiddleLeft'
$lblStatus.Padding = New-Object Windows.Forms.Padding(10, 0, 0, 0)
$form.Controls.Add($lblStatus)

$panelProgress = New-Object Windows.Forms.Panel
$panelProgress.Dock = 'Bottom'
$panelProgress.Height = 36
$panelProgress.BackColor = [Drawing.Color]::FromArgb(236, 240, 245)
$panelProgress.Padding = New-Object Windows.Forms.Padding(12, 8, 12, 8)
$form.Controls.Add($panelProgress)

$lblPercent = New-Object Windows.Forms.Label
$lblPercent.Text = '0%'
$lblPercent.AutoSize = $false
$lblPercent.Width = 48
$lblPercent.Dock = 'Right'
$lblPercent.TextAlign = 'MiddleCenter'
$lblPercent.Font = New-Object Drawing.Font('Segoe UI Semibold', 10)
$lblPercent.ForeColor = [Drawing.Color]::FromArgb(60, 60, 60)
$panelProgress.Controls.Add($lblPercent)

$progress = New-Object Windows.Forms.ProgressBar
$progress.Dock = 'Fill'
$progress.Height = 20
$progress.Minimum = 0
$progress.Maximum = 100
$progress.Value = 0
$progress.Style = 'Continuous'
$panelProgress.Controls.Add($progress)

$split = New-Object Windows.Forms.SplitContainer
$split.Dock = 'Fill'
$split.SplitterDistance = 360
$form.Controls.Add($split)
$form.Controls.SetChildIndex($split, 0)

$grpConfig = New-Object Windows.Forms.GroupBox
$grpConfig.Text = 'Dados deste cliente'
$grpConfig.Dock = 'Fill'
$grpConfig.Padding = New-Object Windows.Forms.Padding(10)
$split.Panel1.Controls.Add($grpConfig)

function New-Lbl([string]$text, [int]$x, [int]$y) {
  $l = New-Object Windows.Forms.Label
  $l.Text = $text
  $l.Location = New-Object Drawing.Point($x, $y)
  $l.AutoSize = $true
  $grpConfig.Controls.Add($l)
}
function Set-Placeholder([System.Windows.Forms.TextBox]$box, [string]$text) {
  if ($null -eq $box) { return }
  $apply = {
    param($sender, $e)
    $msg = $text
    [void][Sil.CueBanner]::SendMessage($sender.Handle, [Sil.CueBanner]::EM_SETCUEBANNER, [IntPtr]1, $msg)
  }.GetNewClosure()
  if ($box.IsHandleCreated) {
    & $apply $box $null
  } else {
    $box.Add_HandleCreated($apply)
  }
}

function New-Txt([int]$x, [int]$y, [int]$w = 300) {
  $t = New-Object Windows.Forms.TextBox
  $t.Location = New-Object Drawing.Point($x, $y)
  $t.Width = $w
  $grpConfig.Controls.Add($t)
  return $t
}

$y = 28
New-Lbl 'Nome do cliente' 16 $y; $y += 18
$txtCliente = New-Txt 16 $y; $y += 32
New-Lbl 'Pasta do projeto (sil)' 16 $y; $y += 18
$txtRepo = New-Txt 16 $y; $y += 32
New-Lbl 'IP da API (visto pelos coletores)' 16 $y; $y += 18
$txtIp = New-Txt 16 $y 180
$btnDetectIp = New-Object Windows.Forms.Button
$btnDetectIp.Text = 'Detectar'
$btnDetectIp.Location = New-Object Drawing.Point(205, ($y - 2))
$btnDetectIp.Width = 90
$grpConfig.Controls.Add($btnDetectIp)
$y += 32
New-Lbl 'Porta' 16 $y
$numPort = New-Object Windows.Forms.NumericUpDown
$numPort.Location = New-Object Drawing.Point(60, ($y - 2))
$numPort.Minimum = 1; $numPort.Maximum = 65535; $numPort.Value = 8080
$numPort.Width = 80
$grpConfig.Controls.Add($numPort)
$y += 32
New-Lbl 'Flutter/Dart (pasta bin)' 16 $y; $y += 18
$txtFlutter = New-Txt 16 $y; $y += 32
New-Lbl 'Pasta de build (sem espaco)' 16 $y; $y += 18
$txtBuild = New-Txt 16 $y; $y += 32
New-Lbl 'Provedor Winthor' 16 $y; $y += 18
$cmbWinthor = New-Object Windows.Forms.ComboBox
$cmbWinthor.DropDownStyle = 'DropDownList'
[void]$cmbWinthor.Items.Add('mock (demonstracao)')
[void]$cmbWinthor.Items.Add('oracle (ERP real)')
$cmbWinthor.Location = New-Object Drawing.Point(16, $y)
$cmbWinthor.Width = 280
$cmbWinthor.SelectedIndex = 0
$grpConfig.Controls.Add($cmbWinthor)
$y += 32
New-Lbl 'Oracle CONN / USER / SENHA' 16 $y; $y += 18
$txtOracleConn = New-Txt 16 $y; $y += 26
$txtOracleUser = New-Txt 16 $y 140
$txtOraclePass = New-Txt 165 $y 140
$txtOraclePass.UseSystemPasswordChar = $true
Set-Placeholder $txtOracleConn 'ex.: host:1521/ORCL'
Set-Placeholder $txtOracleUser 'usuario Oracle'
Set-Placeholder $txtOraclePass 'senha Oracle'
Set-Placeholder $txtCliente 'ex.: RHM Matriz'
Set-Placeholder $txtIp 'ex.: 192.168.0.50'
Set-Placeholder $txtFlutter 'ex.: D:\flutter\bin'
Set-Placeholder $txtBuild 'ex.: D:\sil_build'
$y += 36

$chkRelease = New-Object Windows.Forms.CheckBox
$chkRelease.Text = 'APK release'; $chkRelease.Location = New-Object Drawing.Point(16, $y); $chkRelease.AutoSize = $true; $chkRelease.Checked = $true
$grpConfig.Controls.Add($chkRelease); $y += 24
$chkFirewall = New-Object Windows.Forms.CheckBox
$chkFirewall.Text = 'Liberar firewall da porta'; $chkFirewall.Location = New-Object Drawing.Point(16, $y); $chkFirewall.AutoSize = $true; $chkFirewall.Checked = $true
$grpConfig.Controls.Add($chkFirewall); $y += 24
$chkStartApi = New-Object Windows.Forms.CheckBox
$chkStartApi.Text = 'Iniciar API ao concluir preparo'; $chkStartApi.Location = New-Object Drawing.Point(16, $y); $chkStartApi.AutoSize = $true; $chkStartApi.Checked = $true
$grpConfig.Controls.Add($chkStartApi); $y += 24
$chkStartup = New-Object Windows.Forms.CheckBox
$chkStartup.Text = 'Atalho no logon do Windows'; $chkStartup.Location = New-Object Drawing.Point(16, $y); $chkStartup.AutoSize = $true
$grpConfig.Controls.Add($chkStartup); $y += 24
$chkAdb = New-Object Windows.Forms.CheckBox
$chkAdb.Text = 'Instalar no coletor (ADB) se conectado'; $chkAdb.Location = New-Object Drawing.Point(16, $y); $chkAdb.AutoSize = $true
$grpConfig.Controls.Add($chkAdb)

$cmbWinthor.Add_SelectedIndexChanged({ Update-OracleEnabled })
$btnDetectIp.Add_Click({
  $ips = @(Sil-GetLanIPv4)
  if ($ips.Count -eq 0) {
    [Windows.Forms.MessageBox]::Show('Nenhum IPv4 de LAN detectado.', 'S.I.L.', 'OK', 'Warning') | Out-Null
    return
  }
  $txtIp.Text = $ips[0]
  if ($ips.Count -gt 1) {
    $lista = $ips -join ', '
    Add-LogLine "Varios IPs detectados ($lista). Usando o primeiro: $($ips[0]). Ajuste manualmente se precisar." 'warn'
    [Windows.Forms.MessageBox]::Show(
      "Varios IPs encontrados.`r`n`r`n$lista`r`n`r`nFoi selecionado: $($ips[0])`r`nAltere o campo IP se nao for o da rede dos coletores.",
      'S.I.L. - IP',
      'OK',
      'Information'
    ) | Out-Null
  }
})

$btnPanel = New-Object Windows.Forms.FlowLayoutPanel
$btnPanel.Dock = 'Bottom'
$btnPanel.Height = 48
$btnPanel.Padding = New-Object Windows.Forms.Padding(8)
$split.Panel1.Controls.Add($btnPanel)

$btnStart = New-Object Windows.Forms.Button
$btnStart.Text = 'Iniciar instalacao'
$btnStart.Width = 150; $btnStart.Height = 32
$btnStart.BackColor = [Drawing.Color]::FromArgb(16, 43, 78)
$btnStart.ForeColor = [Drawing.Color]::White
$btnStart.FlatStyle = 'Flat'
$btnPanel.Controls.Add($btnStart)

$btnDry = New-Object Windows.Forms.Button
$btnDry.Text = 'Simular (Dry-Run)'
$btnDry.Width = 130; $btnDry.Height = 32
$btnPanel.Controls.Add($btnDry)

$btnOpen = New-Object Windows.Forms.Button
$btnOpen.Text = 'Abrir pasta APK'
$btnOpen.Width = 120; $btnOpen.Height = 32
$btnPanel.Controls.Add($btnOpen)

$btnLoad = New-Object Windows.Forms.Button
$btnLoad.Text = 'Carregar JSON'
$btnLoad.Width = 110; $btnLoad.Height = 32
$btnPanel.Controls.Add($btnLoad)

$right = New-Object Windows.Forms.SplitContainer
$right.Dock = 'Fill'
$right.Orientation = 'Horizontal'
$right.SplitterDistance = 320
$split.Panel2.Controls.Add($right)

$grpSteps = New-Object Windows.Forms.GroupBox
$grpSteps.Text = 'Procedimentos (acompanhe em tempo real)'
$grpSteps.Dock = 'Fill'
$right.Panel1.Controls.Add($grpSteps)

$panelSteps = New-Object Windows.Forms.Panel
$panelSteps.Dock = 'Fill'
$panelSteps.AutoScroll = $true
$grpSteps.Controls.Add($panelSteps)

$sy = 8
foreach ($s in $script:SilDeploySteps) {
  $l = New-Object Windows.Forms.Label
  $l.AutoSize = $true
  $l.Location = New-Object Drawing.Point(12, $sy)
  $l.Font = New-Object Drawing.Font('Consolas', 9.5)
  $l.Tag = $s.Label
  $l.Text = "[ ]  $($s.Label)"
  $l.ForeColor = [Drawing.Color]::FromArgb(90, 90, 90)
  $panelSteps.Controls.Add($l)
  $script:StepLabels[$s.Id] = $l
  $sy += 24
}

$grpLog = New-Object Windows.Forms.GroupBox
$grpLog.Text = 'Registro detalhado da operacao'
$grpLog.Dock = 'Fill'
$right.Panel2.Controls.Add($grpLog)

$txtLog = New-Object Windows.Forms.TextBox
$txtLog.Multiline = $true
$txtLog.ScrollBars = 'Vertical'
$txtLog.ReadOnly = $true
$txtLog.Dock = 'Fill'
$txtLog.Font = New-Object Drawing.Font('Consolas', 9)
$txtLog.BackColor = [Drawing.Color]::FromArgb(30, 34, 40)
$txtLog.ForeColor = [Drawing.Color]::FromArgb(220, 230, 220)
$grpLog.Controls.Add($txtLog)

$btnStart.Add_Click({ Start-DeployJob $false })
$btnDry.Add_Click({ Start-DeployJob $true })
$btnOpen.Add_Click({
  $dir = Join-Path $PSScriptRoot 'saida'
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  Start-Process explorer.exe $dir
})
$btnLoad.Add_Click({
  $dlg = New-Object Windows.Forms.OpenFileDialog
  $dlg.Filter = 'JSON (*.json)|*.json'
  $dlg.InitialDirectory = $PSScriptRoot
  if ($dlg.ShowDialog() -eq 'OK') {
    try {
      Set-FormConfig (Sil-LoadConfig $dlg.FileName)
      Add-LogLine "Config carregada: $($dlg.FileName)" 'ok'
    } catch {
      [Windows.Forms.MessageBox]::Show($_.Exception.Message, 'S.I.L.', 'OK', 'Error') | Out-Null
    }
  }
})

$form.Add_FormClosing({
  if ($script:IsRunning) {
    $r = [Windows.Forms.MessageBox]::Show('Ha uma instalacao em andamento. Fechar mesmo assim?', 'S.I.L.', 'YesNo', 'Warning')
    if ($r -ne 'Yes') { $_.Cancel = $true; return }
  }
  $timer.Stop()
  Clear-DeployRunspace
})

if ($Config -and (Test-Path $Config)) {
  Set-FormConfig (Sil-LoadConfig $Config)
} else {
  Set-FormConfig (Sil-DefaultConfig)
}
Reset-Steps
Add-LogLine 'Instalador visual pronto. Revise os dados e clique em Iniciar instalacao.' 'info'
Add-LogLine 'Cada procedimento aparece a direita com [>] em andamento e [OK] ao concluir.' 'info'
if (-not (Sil-IsAdmin)) {
  Add-LogLine 'Dica: execute Abrir-Instalador.bat como Administrador para o firewall.' 'warn'
}

[void]$form.ShowDialog()
