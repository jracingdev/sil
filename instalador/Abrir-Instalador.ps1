#Requires -Version 5.1
<#
.SYNOPSIS
  Interface visual do instalador S.I.L. para acompanhamento pelo cliente.

.DESCRIPTION
  Abre uma janela com checklist de procedimentos, formulario de configuracao
  e log em tempo real - para transmitir transparencia e confianca no deploy.

.EXAMPLE
  .\Abrir-Instalador.ps1
#>
param(
  [string]$Config
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

. "$PSScriptRoot\SilEngine.ps1"

[System.Windows.Forms.Application]::EnableVisualStyles()

# ---- state ----
$script:StepLabels = @{}
$script:IsRunning = $false
$script:LastApk = $null

function Add-LogLine([string]$msg, [string]$level) {
  if ($txtLog.IsDisposed) { return }
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

function Set-StepUi([string]$id, [string]$status, [string]$detail) {
  if (-not $script:StepLabels.ContainsKey($id)) { return }
  $lbl = $script:StepLabels[$id]
  $base = $lbl.Tag
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
}

$script:SilLogHandler = {
  param($Message, $Level)
  if ($form.InvokeRequired) {
    $form.BeginInvoke([Action[string,string]]{ param($m,$l) Add-LogLine $m $l }, $Message, $Level) | Out-Null
  } else {
    Add-LogLine $Message $Level
  }
}

$script:SilStepHandler = {
  param($Id, $Status, $Detail)
  if ($form.InvokeRequired) {
    $form.BeginInvoke([Action[string,string,string]]{
      param($i,$s,$d) Set-StepUi $i $s $d
    }, $Id, $Status, $Detail) | Out-Null
  } else {
    Set-StepUi $Id $Status $Detail
  }
}

function Reset-Steps {
  foreach ($s in $script:SilDeploySteps) {
    Set-StepUi $s.Id 'pending' ''
  }
  $lblStatus.Text = 'Pronto para iniciar. Revise os dados a esquerda e clique em Iniciar instalacao.'
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
  $progress.Style = if ($busy) { 'Marquee' } else { 'Blocks' }
  $progress.MarqueeAnimationSpeed = if ($busy) { 30 } else { 0 }
}

# ---- form ----
$form = New-Object Windows.Forms.Form
$form.Text = 'S.I.L. - Instalador visual no cliente'
$form.Size = New-Object Drawing.Size(980, 720)
$form.StartPosition = 'CenterScreen'
$form.MinimumSize = New-Object Drawing.Size(900, 640)
$form.BackColor = [Drawing.Color]::FromArgb(245, 247, 250)
$form.Font = New-Object Drawing.Font('Segoe UI', 9)

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
$lblStatus.Height = 28
$lblStatus.Padding = New-Object Windows.Forms.Padding(12, 6, 12, 4)
$lblStatus.BackColor = [Drawing.Color]::FromArgb(230, 235, 240)
$form.Controls.Add($lblStatus)

$progress = New-Object Windows.Forms.ProgressBar
$progress.Dock = 'Bottom'
$progress.Height = 10
$form.Controls.Add($progress)

# main split
$split = New-Object Windows.Forms.SplitContainer
$split.Dock = 'Fill'
$split.Orientation = 'Vertical'
$split.SplitterDistance = 360
$split.Panel1MinSize = 300
$split.Panel2MinSize = 400
$form.Controls.Add($split)
# bring header back on top visually - dock order: add split first then re-add? 
# Actually dock fill fills remaining; header top and status bottom already added.
# Fix z-order: progress and status should stay at bottom
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
  return $l
}
function New-Txt([int]$x, [int]$y, [int]$w = 300) {
  $t = New-Object Windows.Forms.TextBox
  $t.Location = New-Object Drawing.Point($x, $y)
  $t.Width = $w
  $grpConfig.Controls.Add($t)
  return $t
}

$y = 28
[void](New-Lbl 'Nome do cliente' 16 $y); $y += 18
$txtCliente = New-Txt 16 $y; $y += 32
[void](New-Lbl 'Pasta do projeto (sil)' 16 $y); $y += 18
$txtRepo = New-Txt 16 $y; $y += 32
[void](New-Lbl 'IP da API (visto pelos coletores)' 16 $y); $y += 18
$txtIp = New-Txt 16 $y 180
$btnDetectIp = New-Object Windows.Forms.Button
$btnDetectIp.Text = 'Detectar'
$btnDetectIp.Location = New-Object Drawing.Point(205, ($y - 2))
$btnDetectIp.Width = 90
$grpConfig.Controls.Add($btnDetectIp)
$y += 32
[void](New-Lbl 'Porta' 16 $y)
$numPort = New-Object Windows.Forms.NumericUpDown
$numPort.Location = New-Object Drawing.Point(60, ($y - 2))
$numPort.Minimum = 1; $numPort.Maximum = 65535; $numPort.Value = 8080
$numPort.Width = 80
$grpConfig.Controls.Add($numPort)
$y += 32
[void](New-Lbl 'Flutter/Dart (pasta bin)' 16 $y); $y += 18
$txtFlutter = New-Txt 16 $y; $y += 32
[void](New-Lbl 'Pasta de build (sem espaco)' 16 $y); $y += 18
$txtBuild = New-Txt 16 $y; $y += 32
[void](New-Lbl 'Provedor Winthor' 16 $y); $y += 18
$cmbWinthor = New-Object Windows.Forms.ComboBox
$cmbWinthor.DropDownStyle = 'DropDownList'
$cmbWinthor.Items.AddRange(@('mock (demonstracao)', 'oracle (ERP real)'))
$cmbWinthor.Location = New-Object Drawing.Point(16, $y)
$cmbWinthor.Width = 280
$cmbWinthor.SelectedIndex = 0
$grpConfig.Controls.Add($cmbWinthor)
$y += 32
[void](New-Lbl 'Oracle CONN / USER / SENHA' 16 $y); $y += 18
$txtOracleConn = New-Txt 16 $y; $y += 26
$txtOracleUser = New-Txt 16 $y 140
$txtOraclePass = New-Txt 165 $y 140
$txtOraclePass.UseSystemPasswordChar = $true
$y += 36

$chkRelease = New-Object Windows.Forms.CheckBox
$chkRelease.Text = 'APK release'
$chkRelease.Location = New-Object Drawing.Point(16, $y)
$chkRelease.AutoSize = $true
$chkRelease.Checked = $true
$grpConfig.Controls.Add($chkRelease)
$y += 24
$chkFirewall = New-Object Windows.Forms.CheckBox
$chkFirewall.Text = 'Liberar firewall da porta'
$chkFirewall.Location = New-Object Drawing.Point(16, $y)
$chkFirewall.AutoSize = $true
$chkFirewall.Checked = $true
$grpConfig.Controls.Add($chkFirewall)
$y += 24
$chkStartApi = New-Object Windows.Forms.CheckBox
$chkStartApi.Text = 'Iniciar API ao concluir preparo'
$chkStartApi.Location = New-Object Drawing.Point(16, $y)
$chkStartApi.AutoSize = $true
$chkStartApi.Checked = $true
$grpConfig.Controls.Add($chkStartApi)
$y += 24
$chkStartup = New-Object Windows.Forms.CheckBox
$chkStartup.Text = 'Atalho no logon do Windows'
$chkStartup.Location = New-Object Drawing.Point(16, $y)
$chkStartup.AutoSize = $true
$grpConfig.Controls.Add($chkStartup)
$y += 24
$chkAdb = New-Object Windows.Forms.CheckBox
$chkAdb.Text = 'Instalar no coletor (ADB) se conectado'
$chkAdb.Location = New-Object Drawing.Point(16, $y)
$chkAdb.AutoSize = $true
$grpConfig.Controls.Add($chkAdb)

$cmbWinthor.Add_SelectedIndexChanged({ Update-OracleEnabled })
$btnDetectIp.Add_Click({
  $ips = @(Sil-GetLanIPv4)
  if ($ips.Count -eq 0) {
    [Windows.Forms.MessageBox]::Show('Nenhum IPv4 de LAN detectado.', 'S.I.L.', 'OK', 'Warning') | Out-Null
    return
  }
  if ($ips.Count -eq 1) { $txtIp.Text = $ips[0]; return }
  $pick = $ips | Out-GridView -Title 'Selecione o IP da API' -OutputMode Single
  if ($pick) { $txtIp.Text = $pick }
})

# right panel: steps + log
$right = New-Object Windows.Forms.SplitContainer
$right.Dock = 'Fill'
$right.Orientation = 'Horizontal'
$right.SplitterDistance = 320
$split.Panel2.Controls.Add($right)

$grpSteps = New-Object Windows.Forms.GroupBox
$grpSteps.Text = 'Procedimentos (acompanhe em tempo real)'
$grpSteps.Dock = 'Fill'
$grpSteps.Padding = New-Object Windows.Forms.Padding(8)
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

# buttons bar inside right bottom of config? Put under form as flow on panel1 bottom
$btnPanel = New-Object Windows.Forms.FlowLayoutPanel
$btnPanel.Dock = 'Bottom'
$btnPanel.Height = 48
$btnPanel.Padding = New-Object Windows.Forms.Padding(8)
$btnPanel.FlowDirection = 'LeftToRight'
$split.Panel1.Controls.Add($btnPanel)
$grpConfig.Dock = 'Fill'

$btnStart = New-Object Windows.Forms.Button
$btnStart.Text = 'Iniciar instalacao'
$btnStart.Width = 150
$btnStart.Height = 32
$btnStart.BackColor = [Drawing.Color]::FromArgb(16, 43, 78)
$btnStart.ForeColor = [Drawing.Color]::White
$btnStart.FlatStyle = 'Flat'
$btnPanel.Controls.Add($btnStart)

$btnDry = New-Object Windows.Forms.Button
$btnDry.Text = 'Simular (Dry-Run)'
$btnDry.Width = 130
$btnDry.Height = 32
$btnPanel.Controls.Add($btnDry)

$btnOpen = New-Object Windows.Forms.Button
$btnOpen.Text = 'Abrir pasta APK'
$btnOpen.Width = 120
$btnOpen.Height = 32
$btnPanel.Controls.Add($btnOpen)

$btnLoad = New-Object Windows.Forms.Button
$btnLoad.Text = 'Carregar JSON'
$btnLoad.Width = 110
$btnLoad.Height = 32
$btnPanel.Controls.Add($btnLoad)

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
    [Windows.Forms.MessageBox]::Show("Pasta do projeto nao encontrada:`n$($txtRepo.Text)", 'S.I.L.', 'OK', 'Warning') | Out-Null
    return
  }

  $adminHint = ''
  if ($chkFirewall.Checked -and -not (Sil-IsAdmin)) {
    $adminHint = "`n`nObs: sem Executar como Administrador o firewall pode falhar (o restante segue)."
  }
  $msg = "Sera instalado/configurado o S.I.L. neste computador.`n`nCliente: $($txtCliente.Text)`nAPI: http://$($txtIp.Text):$($numPort.Value)`nModo: $(if($dry){'SIMULACAO'}else{'INSTALACAO REAL'})$adminHint`n`nDeseja continuar?"
  $r = [Windows.Forms.MessageBox]::Show($msg, 'S.I.L. - Confirmacao', 'YesNo', 'Question')
  if ($r -ne 'Yes') { return }

  Reset-Steps
  $txtLog.Clear()
  Set-UiBusy $true
  $cfg = Get-FormConfig

  # Run on thread pool to keep UI responsive
  $state = @{ Dry = $dry; Cfg = $cfg; Form = $form }
  [System.Threading.ThreadPool]::QueueUserWorkItem({
    param($state)
    $dryRun = [bool]$state.Dry
    $config = $state.Cfg
    $ui = $state.Form
    try {
      $res = Sil-RunDeploy -Cfg $config -DoApi $true -DoApk $true -DryRun:$dryRun
      $payload = @{ Res = $res; Dry = $dryRun }
      $ui.BeginInvoke([Action[hashtable]]{
        param($p)
        Set-UiBusy $false
        if ($p.Res.ApkPath) { $script:LastApk = $p.Res.ApkPath }
        $lblStatus.Text = if ($p.Dry) { 'Simulacao concluida.' } else { 'Instalacao concluida com sucesso.' }
        $lblStatus.ForeColor = [Drawing.Color]::FromArgb(20, 120, 60)
        $body = if ($p.Dry) {
          'Simulacao concluida. Revise o log e a lista de procedimentos.'
        } else {
          "Concluido.`r`n`r`nConfig: $($p.Res.ConfigPath)`r`nAPI: $($p.Res.StartScript)`r`nAPK: $($p.Res.ApkPath)"
        }
        [Windows.Forms.MessageBox]::Show($body, 'S.I.L.', 'OK', 'Information') | Out-Null
      }, $payload) | Out-Null
    } catch {
      $err = $_.Exception.Message
      $ui.BeginInvoke([Action[string]]{
        param($e)
        Set-UiBusy $false
        $lblStatus.Text = "Falhou: $e"
        $lblStatus.ForeColor = [Drawing.Color]::FromArgb(180, 40, 40)
        [Windows.Forms.MessageBox]::Show($e, 'S.I.L. - Erro', 'OK', 'Error') | Out-Null
      }, $err) | Out-Null
    }
  }, $state) | Out-Null
}

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

# init
if ($Config -and (Test-Path $Config)) {
  Set-FormConfig (Sil-LoadConfig $Config)
} else {
  Set-FormConfig (Sil-DefaultConfig)
}
Reset-Steps
Add-LogLine 'Instalador visual pronto. Revise os dados e clique em Iniciar instalacao.' 'info'
Add-LogLine 'O cliente pode acompanhar cada procedimento na lista a direita.' 'info'
if (-not (Sil-IsAdmin)) {
  Add-LogLine 'Dica: execute como Administrador para liberar o firewall automaticamente.' 'warn'
}

[void]$form.ShowDialog()
