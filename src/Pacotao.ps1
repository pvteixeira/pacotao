<#
.SYNOPSIS
    Pacotão - Gerenciador e instalador em lote de aplicativos para Windows via Chocolatey.
.DESCRIPTION
    Interface grafica em Windows Forms (PowerShell 5.1+) para selecao, filtro e instalacao
    sequencial de aplicativos essenciais com log em tempo real, modo de simulacao (--noop),
    responsividade de interface via Runspaces e relatorio consolidado de conclusao.
.PARAMETER SkipAdminCheck
    Ignora a verificacao e elevacao automatica UAC de administrador.
.PARAMETER Simular
    Inicia o programa ja com a opcao de simulacao (--noop) marcada por padrao.
#>

[CmdletBinding()]
param(
    [switch]$SkipAdminCheck,
    [switch]$Simular,
    [switch]$IgnoreChecksums,
    [switch]$NoGui
)

# Garantir codificacao UTF-8 para manipulacao de texto em Portugues
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Carregar Assemblies do Windows Forms e Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ==============================================================================
# 1. FUNCOES DE ELEVACAO ADMINISTRATIVA (UAC)
# ==============================================================================

function Test-IsAdmin {
    <#
    .SYNOPSIS
        Verifica se a sessao atual do PowerShell possui privilegios de Administrador.
    #>
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

# Verificacao de elevacao: Se nao for administrador, reabre solicitando elevacao UAC
if (-not $SkipAdminCheck -and -not (Test-IsAdmin)) {
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) {
        $scriptPath = $MyInvocation.MyCommand.Definition
    }

    if ($scriptPath -and (Test-Path $scriptPath)) {
        $arguments = "-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
        if ($Simular) { $arguments += " -Simular" }
        if ($IgnoreChecksums) { $arguments += " -IgnoreChecksums" }

        try {
            Start-Process powershell.exe -WindowStyle Hidden -Verb RunAs -ArgumentList $arguments
            exit 0
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                "O Pacotão necessita de permissoes de Administrador para gerenciar e instalar pacotes pelo Chocolatey.`n`nPor favor, execute o programa como Administrador.",
                "Pacotão - Permissao Necessaria",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
            exit 1
        }
    }
}

# Ocultar a janela do console azul do PowerShell para exibir apenas a interface gráfica
$script:consoleHandle = [IntPtr]::Zero
try {
    $consoleCode = @"
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
"@
    $win32Type = Add-Type -MemberDefinition $consoleCode -Name "Win32ConsoleHelper" -Namespace "PacotaoWin32" -PassThru -ErrorAction SilentlyContinue
    $script:consoleHandle = [PacotaoWin32.Win32ConsoleHelper]::GetConsoleWindow()
    if ($script:consoleHandle -ne [IntPtr]::Zero) {
        [void][PacotaoWin32.Win32ConsoleHelper]::ShowWindow($script:consoleHandle, 0) # 0 = SW_HIDE
    }
}
catch {}

# ==============================================================================
# 2. VERIFICACAO E INSTALACAO OFICIAL DO CHOCOLATEY
# ==============================================================================

function Get-ChocoPath {
    <#
    .SYNOPSIS
        Localiza o executavel choco.exe no PATH ou no diretorio padrao do ProgramData.
    #>
    $cmd = Get-Command choco.exe -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) {
        return $cmd.Source
    }

    $defaultPath = Join-Path $env:ProgramData "chocolatey\bin\choco.exe"
    if (Test-Path $defaultPath) {
        $chocoBin = Join-Path $env:ProgramData "chocolatey\bin"
        if ($env:Path -notlike "*$chocoBin*") {
            $env:Path = "$chocoBin;$env:Path"
        }
        return $defaultPath
    }

    return $null
}

function Test-ChocolateyInstalled {
    <#
    .SYNOPSIS
        Testa se o comando choco esta disponivel e responde a 'choco -v'.
    #>
    $chocoExe = Get-ChocoPath
    if ($chocoExe) {
        try {
            $versionOutput = & $chocoExe -v 2>$null
            if ($LASTEXITCODE -eq 0 -and $versionOutput) {
                return $true
            }
        }
        catch {}
    }
    return $false
}

function Install-ChocolateyOfficialDialog {
    <#
    .SYNOPSIS
        Oferece ao usuario instalar o Chocolatey utilizando exatamente o metodo oficial documentado em https://chocolatey.org/install
    #>
    $officialCommand = "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"

    $msg = "O Chocolatey nao foi detectado no seu computador.`n`n" +
           "O Chocolatey e um gerenciador de pacotes necessario para baixar e instalar os aplicativos do catalogo automaticamente.`n`n" +
           "Deseja instalar o Chocolatey agora utilizando o metodo oficial (chocolatey.org/install)?`n`n" +
           "Comando oficial a ser executado:`n$officialCommand"

    $result = [System.Windows.Forms.MessageBox]::Show(
        $msg,
        "Pacotão - Chocolatey Nao Encontrado",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )

    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        $installForm = New-Object System.Windows.Forms.Form
        $installForm.Text = "Pacotão - Instalando Chocolatey..."
        $installForm.Size = New-Object System.Drawing.Size(650, 400)
        $installForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
        $installForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
        $installForm.MaximizeBox = $false
        $installForm.MinimizeBox = $false

        $lblStatus = New-Object System.Windows.Forms.Label
        $lblStatus.Text = "Baixando e instalando o Chocolatey via script oficial... Aguarde."
        $lblStatus.Location = New-Object System.Drawing.Point(20, 15)
        $lblStatus.Size = New-Object System.Drawing.Size(590, 25)
        $lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
        $installForm.Controls.Add($lblStatus)

        $txtLogChoco = New-Object System.Windows.Forms.TextBox
        $txtLogChoco.Multiline = $true
        $txtLogChoco.ReadOnly = $true
        $txtLogChoco.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
        $txtLogChoco.Location = New-Object System.Drawing.Point(20, 45)
        $txtLogChoco.Size = New-Object System.Drawing.Size(595, 290)
        $txtLogChoco.Font = New-Object System.Drawing.Font("Consolas", 8.5)
        $txtLogChoco.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
        $txtLogChoco.ForeColor = [System.Drawing.Color]::FromArgb(220, 220, 220)
        $installForm.Controls.Add($txtLogChoco)

        $installForm.Show()
        $installForm.Refresh()

        try {
            $txtLogChoco.AppendText("Iniciando instalacao oficial do Chocolatey...`r`n")
            $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $officialCommand 2>&1
            foreach ($line in $output) {
                $txtLogChoco.AppendText("$line`r`n")
                $txtLogChoco.ScrollToCaret()
                [System.Windows.Forms.Application]::DoEvents()
            }

            # Atualizar caminhos de PATH para esta sessao
            $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
            $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
            $env:Path = "$machinePath;$userPath"

            $defaultBin = Join-Path $env:ProgramData "chocolatey\bin"
            if (Test-Path $defaultBin) {
                $env:Path = "$defaultBin;$env:Path"
            }

            Start-Sleep -Seconds 2

            if (Test-ChocolateyInstalled) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Chocolatey instalado com sucesso!`nAgora voce pode instalar qualquer aplicativo do catalogo.",
                    "Pacotão - Sucesso",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null
                $installForm.Close()
                return $true
            }
            else {
                [System.Windows.Forms.MessageBox]::Show(
                    "A instalacao do Chocolatey foi executada, mas o executavel 'choco' ainda nao respondeu no PATH desta sessao.`nRecomenda-se reiniciar a aplicacao.",
                    "Pacotão - Aviso",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                ) | Out-Null
                $installForm.Close()
                return $false
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Ocorreu um erro ao tentar instalar o Chocolatey:`n$($_.Exception.Message)",
                "Pacotão - Erro de Instalacao",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
            $installForm.Close()
            return $false
        }
    }
    else {
        [System.Windows.Forms.MessageBox]::Show(
            "Aviso: Sem o Chocolatey instalado, as instalacoes reais nao serao executadas.`nVoce pode continuar para visualizar o catalogo e testar em modo de simulacao.",
            "Pacotão - Modo Visualizacao",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return $false
    }
}

# ==============================================================================
# 3. LEITURA E VALIDACAO DO CATALOGO APPS.JSON
# ==============================================================================

function Get-CatalogPath {
    <#
    .SYNOPSIS
        Localiza o arquivo apps.json no diretorio do script ou na pasta de trabalho atual.
    #>
    $locations = [System.Collections.Generic.List[string]]::new()
    if ($PSScriptRoot) { $locations.Add($PSScriptRoot) }
    if ($PSCommandPath) {
        $parent = Split-Path -Parent $PSCommandPath
        if ($parent) { $locations.Add($parent) }
    }
    $currentLoc = (Get-Location).Path
    if ($currentLoc) { $locations.Add($currentLoc) }

    foreach ($loc in $locations) {
        if ($loc) {
            $candidate = Join-Path $loc "apps.json"
            if (Test-Path $candidate) {
                return $candidate
            }
        }
    }
    return $null
}

function Load-AppCatalog {
    <#
    .SYNOPSIS
        Carrega e valida o apps.json, aplicando sanitizacao rigorosa de identificadores.
    #>
    $catalogFile = Get-CatalogPath

    if (-not $catalogFile -or -not (Test-Path $catalogFile)) {
        [System.Windows.Forms.MessageBox]::Show(
            "O arquivo de catalogo 'apps.json' nao foi encontrado!`n`nCertifique-se de que o 'apps.json' esteja no mesmo diretorio do 'Pacotao.ps1'.",
            "Pacotão - Erro de Catalogo",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return @()
    }

    try {
        $jsonContent = Get-Content -Path $catalogFile -Raw -Encoding UTF8
        $apps = $jsonContent | ConvertFrom-Json

        $validApps = [System.Collections.Generic.List[psobject]]::new()
        # Regra de seguranca: o ID deve conter apenas caracteres alfanumericos, pontos, hifens ou underscores
        $idRegex = '^[a-zA-Z0-9\.\-_]+$'

        foreach ($app in $apps) {
            if (-not $app.id -or -not $app.nome -or -not $app.categoria) {
                continue
            }

            if ($app.id -notmatch $idRegex) {
                Write-Warning "Aplicativo com ID invalido descartado por seguranca: $($app.id)"
                continue
            }

            $validApps.Add([PSCustomObject]@{
                id         = [string]$app.id.Trim()
                nome       = [string]$app.nome.Trim()
                categoria  = [string]$app.categoria.Trim()
                padrao     = [bool]($app.padrao -eq $true)
                url        = if ($app.url) { [string]$app.url.Trim() } else { $null }
                argumentos = if ($app.argumentos) { [string]$app.argumentos.Trim() } else { $null }
            })
        }

        return $validApps
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Falha ao ler ou interpretar o arquivo 'apps.json':`n$($_.Exception.Message)",
            "Pacotão - Erro no JSON",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return @()
    }
}

# ==============================================================================
# 4. GESTAO DE LOGS EM DISCO
# ==============================================================================

function Get-LogDirectory {
    $dir = Join-Path $env:USERPROFILE "Pacotao\logs"
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
    return $dir
}

function Save-SessionLogFile {
    param(
        [string]$LogContent,
        [psobject]$Summary
    )

    try {
        $logDir = Get-LogDirectory
        $timestamp = (Get-Date).ToString("yyyy-MM-dd_HH-mm-ss")
        $logFile = Join-Path $logDir "pacotao_$timestamp.log"

        $header = @"
================================================================================
PACOTAO - RELATORIO DE SESSAO
Data/Hora: $(Get-Date -Format "dd/MM/yyyy HH:mm:ss")
Usuario: $env:USERNAME
Computador: $env:COMPUTERNAME
================================================================================

RESUMO FINAL:
- Instalados com Sucesso: $($Summary.Installed.Count)
- Ja Instalados (Inalterados): $($Summary.AlreadyInstalled.Count)
- Requerem Reinicializacao: $($Summary.RebootRequired.Count)
- Falhas na Instalacao: $($Summary.Failed.Count)

================================================================================
REGISTRO DETALHADO DA OPERACAO:
================================================================================

"@
        $finalContent = $header + $LogContent
        [System.IO.File]::WriteAllText($logFile, $finalContent, [System.Text.Encoding]::UTF8)
        return $logFile
    }
    catch {
        return $null
    }
}

# ==============================================================================
# 5. CONSTRUCAO DA INTERFACE GRAFICA (WINDOWS FORMS)
# ==============================================================================

function Show-PacotaoMainWindow {
    # Carregar catalogo
    $catalog = Load-AppCatalog
    if (-not $catalog -or $catalog.Count -eq 0) {
        return
    }

    # Verificar Chocolatey
    $chocoPresent = Test-ChocolateyInstalled
    if (-not $chocoPresent) {
        $chocoPresent = Install-ChocolateyOfficialDialog
    }

    # Janela Principal
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Pacotão - Instalador em Lote via Chocolatey"
    $form.Size = New-Object System.Drawing.Size(1020, 750)
    $form.MinimumSize = New-Object System.Drawing.Size(880, 640)
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.BackColor = [System.Drawing.Color]::FromArgb(248, 249, 250)
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

    # --------------------------------------------------------------------------
    # Cabecalho Superior
    # --------------------------------------------------------------------------
    $headerPanel = New-Object System.Windows.Forms.Panel
    $headerPanel.Dock = [System.Windows.Forms.DockStyle]::Top
    $headerPanel.Height = 85
    $headerPanel.BackColor = [System.Drawing.Color]::FromArgb(25, 42, 86)
    $form.Controls.Add($headerPanel)

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "Pacotão"
    $lblTitle.ForeColor = [System.Drawing.Color]::White
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Location = New-Object System.Drawing.Point(20, 12)
    $lblTitle.AutoSize = $true
    $headerPanel.Controls.Add($lblTitle)

    $lblSubtitle = New-Object System.Windows.Forms.Label
    $lblSubtitle.Text = "Selecione os aplicativos essenciais para instalar em sequencia e com seguranca"
    $lblSubtitle.ForeColor = [System.Drawing.Color]::FromArgb(200, 214, 229)
    $lblSubtitle.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
    $lblSubtitle.Location = New-Object System.Drawing.Point(23, 48)
    $lblSubtitle.AutoSize = $true
    $headerPanel.Controls.Add($lblSubtitle)

    # Checkbox de Modo de Simulacao (--noop)
    $chkSimulation = New-Object System.Windows.Forms.CheckBox
    $chkSimulation.Text = "Apenas simular (--noop)"
    $chkSimulation.ForeColor = [System.Drawing.Color]::FromArgb(254, 202, 87)
    $chkSimulation.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $chkSimulation.Location = New-Object System.Drawing.Point(740, 16)
    $chkSimulation.AutoSize = $true
    $chkSimulation.Checked = [bool]$Simular
    $chkSimulation.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
    $chkSimulationToolTip = New-Object System.Windows.Forms.ToolTip
    $chkSimulationToolTip.SetToolTip($chkSimulation, "Quando marcado, adiciona o parametro --noop aos comandos do Chocolatey.`nNenhum programa sera realmente instalado ou alterado no seu computador.")
    $headerPanel.Controls.Add($chkSimulation)

    # Checkbox de Ignorar Checksum (--ignore-checksums)
    $chkIgnoreChecksums = New-Object System.Windows.Forms.CheckBox
    $chkIgnoreChecksums.Text = "Ignorar checksums (--ignore-checksums)"
    $chkIgnoreChecksums.ForeColor = [System.Drawing.Color]::FromArgb(254, 202, 87)
    $chkIgnoreChecksums.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $chkIgnoreChecksums.Location = New-Object System.Drawing.Point(740, 46)
    $chkIgnoreChecksums.AutoSize = $true
    $chkIgnoreChecksums.Checked = [bool]$IgnoreChecksums
    $chkIgnoreChecksums.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
    $chkIgnoreChecksumsToolTip = New-Object System.Windows.Forms.ToolTip
    $chkIgnoreChecksumsToolTip.SetToolTip($chkIgnoreChecksums, "Permite instalar pacotes mesmo se o hash do arquivo baixado (como Google Chrome) for diferente do esperado pelo Chocolatey.")
    $headerPanel.Controls.Add($chkIgnoreChecksums)

    # --------------------------------------------------------------------------
    # Barra de Filtro e Selecao Rapida
    # --------------------------------------------------------------------------
    $toolbarPanel = New-Object System.Windows.Forms.Panel
    $toolbarPanel.Dock = [System.Windows.Forms.DockStyle]::Top
    $toolbarPanel.Height = 50
    $toolbarPanel.BackColor = [System.Drawing.Color]::FromArgb(241, 242, 246)
    $form.Controls.Add($toolbarPanel)

    $txtSearch = New-Object System.Windows.Forms.TextBox
    $txtSearch.Location = New-Object System.Drawing.Point(20, 12)
    $txtSearch.Size = New-Object System.Drawing.Size(320, 26)
    $txtSearch.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
    $txtSearch.ForeColor = [System.Drawing.Color]::Gray
    $txtSearch.Text = "Filtrar por nome, ID ou categoria..."
    $toolbarPanel.Controls.Add($txtSearch)

    $btnSelectAll = New-Object System.Windows.Forms.Button
    $btnSelectAll.Text = "Marcar Todos"
    $btnSelectAll.Location = New-Object System.Drawing.Point(355, 11)
    $btnSelectAll.Size = New-Object System.Drawing.Size(100, 28)
    $btnSelectAll.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnSelectAll.BackColor = [System.Drawing.Color]::White
    $toolbarPanel.Controls.Add($btnSelectAll)

    $btnDeselectAll = New-Object System.Windows.Forms.Button
    $btnDeselectAll.Text = "Desmarcar Todos"
    $btnDeselectAll.Location = New-Object System.Drawing.Point(462, 11)
    $btnDeselectAll.Size = New-Object System.Drawing.Size(120, 28)
    $btnDeselectAll.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnDeselectAll.BackColor = [System.Drawing.Color]::White
    $toolbarPanel.Controls.Add($btnDeselectAll)

    $btnSelectDefault = New-Object System.Windows.Forms.Button
    $btnSelectDefault.Text = "Padrao"
    $btnSelectDefault.Location = New-Object System.Drawing.Point(589, 11)
    $btnSelectDefault.Size = New-Object System.Drawing.Size(85, 28)
    $btnSelectDefault.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnSelectDefault.BackColor = [System.Drawing.Color]::White
    $toolbarPanel.Controls.Add($btnSelectDefault)

    $lblCount = New-Object System.Windows.Forms.Label
    $lblCount.Text = "0 selecionados"
    $lblCount.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $lblCount.ForeColor = [System.Drawing.Color]::FromArgb(47, 53, 66)
    $lblCount.Location = New-Object System.Drawing.Point(690, 16)
    $lblCount.AutoSize = $true
    $toolbarPanel.Controls.Add($lblCount)

    # --------------------------------------------------------------------------
    # Rodape Inferior de Acoes
    # --------------------------------------------------------------------------
    $bottomPanel = New-Object System.Windows.Forms.Panel
    $bottomPanel.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $bottomPanel.Height = 65
    $bottomPanel.BackColor = [System.Drawing.Color]::FromArgb(241, 242, 246)
    $form.Controls.Add($bottomPanel)

    $btnOpenLogs = New-Object System.Windows.Forms.Button
    $btnOpenLogs.Text = "Abrir Pasta de Logs"
    $btnOpenLogs.Location = New-Object System.Drawing.Point(20, 16)
    $btnOpenLogs.Size = New-Object System.Drawing.Size(160, 34)
    $btnOpenLogs.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnOpenLogs.BackColor = [System.Drawing.Color]::White
    $bottomPanel.Controls.Add($btnOpenLogs)

    $btnUpgradeAll = New-Object System.Windows.Forms.Button
    $btnUpgradeAll.Text = "Atualizar Tudo"
    $btnUpgradeAll.Location = New-Object System.Drawing.Point(190, 16)
    $btnUpgradeAll.Size = New-Object System.Drawing.Size(140, 34)
    $btnUpgradeAll.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnUpgradeAll.BackColor = [System.Drawing.Color]::White
    $bottomPanel.Controls.Add($btnUpgradeAll)

    $btnRetryFailed = New-Object System.Windows.Forms.Button
    $btnRetryFailed.Text = "Tentar Novamente os que Falharam"
    $btnRetryFailed.Location = New-Object System.Drawing.Point(510, 16)
    $btnRetryFailed.Size = New-Object System.Drawing.Size(240, 34)
    $btnRetryFailed.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnRetryFailed.BackColor = [System.Drawing.Color]::FromArgb(255, 234, 167)
    $btnRetryFailed.ForeColor = [System.Drawing.Color]::FromArgb(180, 83, 9)
    $btnRetryFailed.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $btnRetryFailed.Visible = $false
    $btnRetryFailed.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
    $bottomPanel.Controls.Add($btnRetryFailed)

    $btnInstall = New-Object System.Windows.Forms.Button
    $btnInstall.Text = "Instalar Selecionados"
    $btnInstall.Location = New-Object System.Drawing.Point(760, 15)
    $btnInstall.Size = New-Object System.Drawing.Size(225, 36)
    $btnInstall.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnInstall.BackColor = [System.Drawing.Color]::FromArgb(9, 132, 227)
    $btnInstall.ForeColor = [System.Drawing.Color]::White
    $btnInstall.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btnInstall.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnInstall.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
    $bottomPanel.Controls.Add($btnInstall)

    # --------------------------------------------------------------------------
    # SplitContainer Central: Lista (Topo) x Progresso e Log (Baixo)
    # --------------------------------------------------------------------------
    $splitCentral = New-Object System.Windows.Forms.SplitContainer
    $splitCentral.Dock = [System.Windows.Forms.DockStyle]::Fill
    $splitCentral.Orientation = [System.Windows.Forms.Orientation]::Horizontal
    $splitCentral.SplitterDistance = 320
    $splitCentral.SplitterWidth = 6
    $form.Controls.Add($splitCentral)
    $splitCentral.BringToFront()

    # ListView de Aplicativos
    $listViewApps = New-Object System.Windows.Forms.ListView
    $listViewApps.Dock = [System.Windows.Forms.DockStyle]::Fill
    $listViewApps.View = [System.Windows.Forms.View]::Details
    $listViewApps.CheckBoxes = $true
    $listViewApps.FullRowSelect = $true
    $listViewApps.GridLines = $true
    $listViewApps.ShowGroups = $true
    $listViewApps.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
    $splitCentral.Panel1.Controls.Add($listViewApps)

    [void]$listViewApps.Columns.Add("Aplicativo", 300)
    [void]$listViewApps.Columns.Add("ID / Pacote", 160)
    [void]$listViewApps.Columns.Add("Categoria", 150)
    [void]$listViewApps.Columns.Add("Status", 360)

    # Painel de Progresso
    $progressPanel = New-Object System.Windows.Forms.Panel
    $progressPanel.Dock = [System.Windows.Forms.DockStyle]::Top
    $progressPanel.Height = 55
    $progressPanel.BackColor = [System.Drawing.Color]::FromArgb(248, 249, 250)
    $splitCentral.Panel2.Controls.Add($progressPanel)

    $lblProgress = New-Object System.Windows.Forms.Label
    $lblProgress.Text = "Pronto para iniciar. Selecione os aplicativos e clique em 'Instalar Selecionados'."
    $lblProgress.Location = New-Object System.Drawing.Point(15, 6)
    $lblProgress.Size = New-Object System.Drawing.Size(950, 20)
    $lblProgress.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $lblProgress.ForeColor = [System.Drawing.Color]::FromArgb(47, 53, 66)
    $lblProgress.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $progressPanel.Controls.Add($lblProgress)

    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(15, 27)
    $progressBar.Size = New-Object System.Drawing.Size(970, 20)
    $progressBar.Minimum = 0
    $progressBar.Maximum = 100
    $progressBar.Value = 0
    $progressBar.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $progressPanel.Controls.Add($progressBar)

    # Caixa de Log em Tempo Real
    $txtLog = New-Object System.Windows.Forms.TextBox
    $txtLog.Dock = [System.Windows.Forms.DockStyle]::Fill
    $txtLog.Multiline = $true
    $txtLog.ReadOnly = $true
    $txtLog.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
    $txtLog.WordWrap = $false
    $txtLog.BackColor = [System.Drawing.Color]::FromArgb(26, 26, 26)
    $txtLog.ForeColor = [System.Drawing.Color]::FromArgb(220, 221, 225)
    $txtLog.Font = New-Object System.Drawing.Font("Consolas", 9)
    $splitCentral.Panel2.Controls.Add($txtLog)
    $txtLog.BringToFront()

    # --------------------------------------------------------------------------
    # ESTADO E CONTROLE DA INTERFACE
    # --------------------------------------------------------------------------
    $appSelection = @{}
    $appStatus = @{}
    $catalogDict = @{}
    $categoryGroups = @{}

    foreach ($app in $catalog) {
        $appSelection[$app.id] = $app.padrao
        $appStatus[$app.id] = "Pendente"
        $catalogDict[$app.id] = $app
    }

    $script:isUpdatingList = $false
    function Refresh-ListView {
        param([string]$Filter = "")

        $script:isUpdatingList = $true
        $listViewApps.BeginUpdate()
        $listViewApps.Items.Clear()
        $listViewApps.Groups.Clear()
        $categoryGroups.Clear()

        $normFilter = $Filter.Trim().ToLower()

        foreach ($app in $catalog) {
            if ($normFilter -and $normFilter -ne "filtrar por nome, id ou categoria...") {
                $matchNome = $app.nome.ToLower().Contains($normFilter)
                $matchId = $app.id.ToLower().Contains($normFilter)
                $matchCat = $app.categoria.ToLower().Contains($normFilter)
                if (-not ($matchNome -or $matchId -or $matchCat)) {
                    continue
                }
            }

            if (-not $categoryGroups.ContainsKey($app.categoria)) {
                $group = New-Object System.Windows.Forms.ListViewGroup($app.categoria, $app.categoria)
                [void]$listViewApps.Groups.Add($group)
                $categoryGroups[$app.categoria] = $group
            }

            $item = New-Object System.Windows.Forms.ListViewItem($app.nome)
            $item.Tag = $app.id
            $item.Group = $categoryGroups[$app.categoria]
            $item.Checked = [bool]$appSelection[$app.id]

            [void]$item.SubItems.Add($app.id)
            [void]$item.SubItems.Add($app.categoria)
            [void]$item.SubItems.Add($appStatus[$app.id])

            switch -Wildcard ($appStatus[$app.id]) {
                "*Instalando*" {
                    $item.ForeColor = [System.Drawing.Color]::FromArgb(9, 132, 227)
                }
                "*Sucesso*" {
                    $item.ForeColor = [System.Drawing.Color]::FromArgb(46, 125, 50)
                }
                "*Ja instalado*" {
                    $item.ForeColor = [System.Drawing.Color]::FromArgb(56, 142, 60)
                }
                "*Reinicializacao*" {
                    $item.ForeColor = [System.Drawing.Color]::FromArgb(217, 119, 6)
                }
                "*Falhou*" {
                    $item.ForeColor = [System.Drawing.Color]::FromArgb(214, 48, 49)
                }
                default {
                    $item.ForeColor = [System.Drawing.Color]::Black
                }
            }

            [void]$listViewApps.Items.Add($item)
        }

        $listViewApps.EndUpdate()
        $script:isUpdatingList = $false
        Update-SelectionCounter
    }

    function Update-SelectionCounter {
        $selectedCount = 0
        foreach ($val in $appSelection.Values) {
            if ($val) { $selectedCount++ }
        }
        $lblCount.Text = "$selectedCount de $($catalog.Count) selecionados"
        $btnInstall.Text = "Instalar Selecionados ($selectedCount)"
    }

    $listViewApps.add_ItemChecked({
        param($sender, $e)
        if ($script:isUpdatingList) { return }
        $appId = $e.Item.Tag
        if ($appId) {
            $appSelection[$appId] = $e.Item.Checked
            Update-SelectionCounter
        }
    })

    $txtSearch.add_GotFocus({
        if ($txtSearch.Text -eq "Filtrar por nome, ID ou categoria...") {
            $txtSearch.Text = ""
            $txtSearch.ForeColor = [System.Drawing.Color]::Black
        }
    })

    $txtSearch.add_LostFocus({
        if ([string]::IsNullOrWhiteSpace($txtSearch.Text)) {
            $txtSearch.Text = "Filtrar por nome, ID ou categoria..."
            $txtSearch.ForeColor = [System.Drawing.Color]::Gray
        }
    })

    $txtSearch.add_TextChanged({
        Refresh-ListView -Filter $txtSearch.Text
    })

    $btnSelectAll.add_Click({
        foreach ($key in @($appSelection.Keys)) {
            $appSelection[$key] = $true
        }
        Refresh-ListView -Filter $txtSearch.Text
    })

    $btnDeselectAll.add_Click({
        foreach ($key in @($appSelection.Keys)) {
            $appSelection[$key] = $false
        }
        Refresh-ListView -Filter $txtSearch.Text
    })

    $btnSelectDefault.add_Click({
        foreach ($app in $catalog) {
            $appSelection[$app.id] = $app.padrao
        }
        Refresh-ListView -Filter $txtSearch.Text
    })

    $btnOpenLogs.add_Click({
        $dir = Get-LogDirectory
        Start-Process explorer.exe -ArgumentList "`"$dir`""
    })

    $btnRetryFailed.add_Click({
        $hasFailed = $false
        foreach ($app in $catalog) {
            if ($appStatus[$app.id] -like "*Falhou*") {
                $appSelection[$app.id] = $true
                $hasFailed = $true
            }
            else {
                $appSelection[$app.id] = $false
            }
        }

        if ($hasFailed) {
            Refresh-ListView -Filter $txtSearch.Text
            $btnInstall.PerformClick()
        }
    })

    # --------------------------------------------------------------------------
    # RUNSPACE COM FILA THREAD-SAFE
    # --------------------------------------------------------------------------
    $syncHash = [hashtable]::Synchronized(@{
        Queue            = New-Object System.Collections.Concurrent.ConcurrentQueue[psobject]
        IsRunning        = $false
        CancelRequested  = $false
        AppsQueue        = @()
        ActionType       = "Install"
        SimulationMode   = $false
        IgnoreChecksums  = $false
        ChocoExecutable  = (Get-ChocoPath)
        CapturedLogs     = [System.Text.StringBuilder]::new()
    })

    $uiTimer = New-Object System.Windows.Forms.Timer
    $uiTimer.Interval = 100

    $uiTimer.add_Tick({
        $item = $null
        while ($syncHash.Queue.TryDequeue([ref]$item)) {
            if (-not $item) { continue }

            switch ($item.Type) {
                "Log" {
                    $txtLog.AppendText($item.Message)
                    $txtLog.ScrollToCaret()
                    [void]$syncHash.CapturedLogs.Append($item.Message)
                }
                "Progress" {
                    $progressBar.Value = [Math]::Min(100, [Math]::Max(0, [int]$item.Percent))
                    $lblProgress.Text = $item.Text
                }
                "AppStatus" {
                    $appStatus[$item.AppId] = $item.StatusText
                    foreach ($lvItem in $listViewApps.Items) {
                        if ($lvItem.Tag -eq $item.AppId) {
                            $lvItem.SubItems[3].Text = $item.StatusText
                            switch -Wildcard ($item.StatusText) {
                                "*Instalando*" { $lvItem.ForeColor = [System.Drawing.Color]::FromArgb(9, 132, 227) }
                                "*Sucesso*" { $lvItem.ForeColor = [System.Drawing.Color]::FromArgb(46, 125, 50) }
                                "*Ja instalado*" { $lvItem.ForeColor = [System.Drawing.Color]::FromArgb(56, 142, 60) }
                                "*Reinicializacao*" { $lvItem.ForeColor = [System.Drawing.Color]::FromArgb(217, 119, 6) }
                                "*Falhou*" { $lvItem.ForeColor = [System.Drawing.Color]::FromArgb(214, 48, 49) }
                            }
                            break
                        }
                    }
                }
                "Complete" {
                    $uiTimer.Stop()
                    $syncHash.IsRunning = $false

                    $savedLogFile = Save-SessionLogFile -LogContent ($syncHash.CapturedLogs.ToString()) -Summary $item.Summary

                    $btnInstall.Enabled = $true
                    $btnUpgradeAll.Enabled = $true
                    $btnSelectAll.Enabled = $true
                    $btnDeselectAll.Enabled = $true
                    $btnSelectDefault.Enabled = $true
                    $chkSimulation.Enabled = $true
                    $chkIgnoreChecksums.Enabled = $true
                    $txtSearch.Enabled = $true

                    if ($item.Summary.Failed.Count -gt 0) {
                        $btnRetryFailed.Visible = $true
                    }
                    else {
                        $btnRetryFailed.Visible = $false
                    }

                    $progressBar.Value = 100
                    $lblProgress.Text = "Operacao concluida. Resumo disponivel abaixo."

                    $summaryMsg = "Operacao finalizada!`n`n" +
                                  "[OK] Instalados com sucesso: $($item.Summary.Installed.Count)`n" +
                                  "[INFO] Ja estavam instalados: $($item.Summary.AlreadyInstalled.Count)`n" +
                                  "[AVISO] Requerem reinicializacao: $($item.Summary.RebootRequired.Count)`n" +
                                  "[ERRO] Falharam: $($item.Summary.Failed.Count)`n"

                    if ($item.Summary.Failed.Count -gt 0) {
                        $failedNames = ($item.Summary.Failed | ForEach-Object { "$($_.Nome) ($($_.Id))" }) -join ", "
                        $summaryMsg += "`nAplicativos com falha:`n$failedNames`n`nVoce pode usar o botao 'Tentar Novamente os que Falharam' para reprocessa-los."
                    }

                    if ($savedLogFile) {
                        $summaryMsg += "`n`nArquivo de log salvo em:`n$savedLogFile"
                    }

                    $icon = if ($item.Summary.Failed.Count -gt 0) {
                        [System.Windows.Forms.MessageBoxIcon]::Warning
                    } else {
                        [System.Windows.Forms.MessageBoxIcon]::Information
                    }

                    [System.Windows.Forms.MessageBox]::Show(
                        $summaryMsg,
                        "Pacotão - Resumo da Operacao",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        $icon
                    ) | Out-Null
                }
            }
        }
    })

    # Bloco de codigo executado no Runspace em segundo plano
    $workerScriptBlock = {
        param($state)

        function Send-QueueLog {
            param([string]$text)
            $state.Queue.Enqueue([PSCustomObject]@{
                Type    = "Log"
                Message = $text
            })
        }

        function Send-QueueProgress {
            param([int]$pct, [string]$txt)
            $state.Queue.Enqueue([PSCustomObject]@{
                Type    = "Progress"
                Percent = $pct
                Text    = $txt
            })
        }

        function Send-QueueAppStatus {
            param([string]$appId, [string]$status)
            $state.Queue.Enqueue([PSCustomObject]@{
                Type       = "AppStatus"
                AppId      = $appId
                StatusText = $status
            })
        }

        $summary = [PSCustomObject]@{
            Installed        = [System.Collections.Generic.List[psobject]]::new()
            AlreadyInstalled = [System.Collections.Generic.List[psobject]]::new()
            RebootRequired   = [System.Collections.Generic.List[psobject]]::new()
            Failed           = [System.Collections.Generic.List[psobject]]::new()
        }

        $chocoExe = $state.ChocoExecutable
        $simular = $state.SimulationMode

        # Caso o Chocolatey nao esteja instalado
        if (-not $chocoExe -or -not (Test-Path $chocoExe)) {
            if ($simular) {
                Send-QueueLog "AVISO: Chocolatey nao detectado no sistema, mas modo SIMULACAO esta ativo.`r`n"
                Send-QueueLog "Executando simulacao virtual dos pacotes sem instalacao real...`r`n`r`n"
            }
            else {
                # Verifica se ha aplicativos que precisam do Chocolatey
                $needsChoco = $false
                if ($state.ActionType -eq "Install") {
                    foreach ($chkApp in $state.AppsQueue) {
                        if (-not $chkApp.url) {
                            $needsChoco = $true
                            break
                        }
                    }
                }
                else {
                    $needsChoco = $true
                }

                if ($needsChoco) {
                    Send-QueueLog "AVISO: Executavel do Chocolatey (choco.exe) nao foi encontrado no sistema.`r`n"
                    Send-QueueLog "Aplicativos que dependem do Chocolatey falharao, mas pacotes com download direto continuarao.`r`n`r`n"
                }
            }
        }

        # ----------------------------------------------------------------------
        # ACAO: Instalar Fila de Aplicativos
        # ----------------------------------------------------------------------
        if ($state.ActionType -eq "Install") {
            $appsToRun = $state.AppsQueue
            $total = $appsToRun.Count

            Send-QueueLog "================================================================================`r`n"
            Send-QueueLog "Iniciando processamento sequencial de $total aplicativo(s)...`r`n"
            if ($simular) {
                Send-QueueLog "[MODO SIMULACAO ATIVO] Nenhuma alteracao real sera realizada (--noop).`r`n"
            }
            Send-QueueLog "================================================================================`r`n`r`n"

            $currentIndex = 0

            foreach ($app in $appsToRun) {
                if ($state.CancelRequested) {
                    Send-QueueLog "`r`nProcessamento cancelado pelo usuario.`r`n"
                    break
                }

                $currentIndex++
                $appId = $app.id
                $appName = $app.nome
                $appUrl = $app.url
                $appArgs = $app.argumentos

                $pct = [int](($currentIndex - 1) / [Math]::Max(1, $total) * 100)
                Send-QueueProgress $pct "Processando $currentIndex de ${total}: $appName ($appId)..."
                Send-QueueAppStatus $appId "Instalando..."
                Send-QueueLog "[$currentIndex/$total] Instalando $appName (ID: $appId)...`r`n"

                # --------------------------------------------------------------
                # ROTA A: Download Direto via URL (Certificado Digital, Tokens, etc.)
                # --------------------------------------------------------------
                if ($appUrl) {
                    if ($simular) {
                        Start-Sleep -Milliseconds 600
                        Send-QueueLog "  | [SIMULADO] Download direto de URL: $appUrl`r`n"
                        if ($appArgs) {
                            Send-QueueLog "  | [SIMULADO] Execucao do instalador com parametros: $appArgs`r`n"
                        } else {
                            Send-QueueLog "  | [SIMULADO] Execucao do instalador em modo assistido.`r`n"
                        }
                        Send-QueueAppStatus $appId "Sucesso (Simulado)"
                        Send-QueueLog "  -> $appName verificado com sucesso em modo simulacao!`r`n`r`n"
                        $summary.Installed.Add([PSCustomObject]@{ Id = $appId; Nome = $appName })
                        continue
                    }

                    # Diretorio temporario de downloads
                    $downloadsDir = Join-Path $env:TEMP "pacotao_Downloads"
                    if (-not (Test-Path $downloadsDir)) {
                        New-Item -Path $downloadsDir -ItemType Directory -Force | Out-Null
                    }

                    $urlFileName = [System.IO.Path]::GetFileName($appUrl)
                    if (-not $urlFileName -or $urlFileName -notlike "*.exe") {
                        $urlFileName = "$appId.exe"
                    }
                    $installerPath = Join-Path $downloadsDir $urlFileName

                    # Baixar instalador
                    Send-QueueAppStatus $appId "Baixando..."
                    Send-QueueLog "  | Baixando instalador oficial de:`r`n  | $appUrl`r`n"

                    $downloadOk = $false
                    $webClient = $null
                    try {
                        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
                        $webClient = New-Object System.Net.WebClient
                        $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Pacotão")
                        $webClient.DownloadFile($appUrl, $installerPath)
                        $fileSizeMb = [math]::Round(((Get-Item $installerPath).Length / 1MB), 2)
                        Send-QueueLog "  | Download concluido com exito ($fileSizeMb MB). Arquivo: $urlFileName`r`n"
                        $downloadOk = $true
                    }
                    catch {
                        Send-QueueAppStatus $appId "Falhou"
                        Send-QueueLog "  -> ERRO no download de ${appName}: $($_.Exception.Message)`r`n`r`n"
                        $summary.Failed.Add([PSCustomObject]@{ Id = $appId; Nome = $appName; Code = -1 })
                    }
                    finally {
                        if ($webClient) { $webClient.Dispose() }
                    }

                    if (-not $downloadOk) {
                        continue
                    }

                    # Executar instalador
                    Send-QueueAppStatus $appId "Instalando..."
                    Send-QueueLog "  | Executando instalador $urlFileName"
                    if ($appArgs) {
                        Send-QueueLog " com argumentos: $appArgs`r`n"
                    } else {
                        Send-QueueLog "...`r`n"
                    }

                    $psi = New-Object System.Diagnostics.ProcessStartInfo
                    $psi.FileName = $installerPath
                    if ($appArgs) {
                        $psi.Arguments = $appArgs
                    }
                    $psi.UseShellExecute = $true

                    $proc = $null
                    try {
                        $proc = [System.Diagnostics.Process]::Start($psi)
                        $proc.WaitForExit()
                        $exitCode = $proc.ExitCode

                        if ($exitCode -eq 0) {
                            Send-QueueAppStatus $appId "Sucesso"
                            Send-QueueLog "  -> $appName instalado com sucesso! (Codigo: 0)`r`n`r`n"
                            $summary.Installed.Add([PSCustomObject]@{ Id = $appId; Nome = $appName })
                        }
                        elseif ($exitCode -eq 1641 -or $exitCode -eq 3010) {
                            Send-QueueAppStatus $appId "Requer reinicializacao"
                            Send-QueueLog "  -> $appName instalado com sucesso, mas requer reinicializacao do Windows. (Codigo: $exitCode)`r`n`r`n"
                            $summary.RebootRequired.Add([PSCustomObject]@{ Id = $appId; Nome = $appName; Code = $exitCode })
                        }
                        else {
                            Send-QueueAppStatus $appId "Falhou"
                            Send-QueueLog "  -> Instalador de $appName finalizou com codigo de saida: $exitCode`r`n`r`n"
                            $summary.Failed.Add([PSCustomObject]@{ Id = $appId; Nome = $appName; Code = $exitCode })
                        }
                    }
                    catch {
                        Send-QueueAppStatus $appId "Falhou"
                        Send-QueueLog "  -> Excecao ao executar instalador de ${appId}: $($_.Exception.Message)`r`n`r`n"
                        $summary.Failed.Add([PSCustomObject]@{ Id = $appId; Nome = $appName; Code = -1 })
                    }
                    finally {
                        if ($proc) { $proc.Dispose() }
                    }

                    continue
                }

                # --------------------------------------------------------------
                # ROTA B: Instalacao via Chocolatey
                # --------------------------------------------------------------
                if (-not $chocoExe -or -not (Test-Path $chocoExe)) {
                    if ($simular) {
                        Start-Sleep -Milliseconds 600
                        Send-QueueLog "  | [SIMULADO] choco install $appId -y --no-progress --noop`r`n"
                        Send-QueueLog "  | Chocolatey v2.0.0 (simulado)`r`n"
                        Send-QueueLog "  | Installing $appId... Done.`r`n"
                        Send-QueueAppStatus $appId "Sucesso (Simulado)"
                        Send-QueueLog "  -> $appName verificado com sucesso em modo simulacao!`r`n`r`n"
                        $summary.Installed.Add([PSCustomObject]@{ Id = $appId; Nome = $appName })
                        continue
                    }
                    else {
                        Send-QueueAppStatus $appId "Falhou"
                        Send-QueueLog "  -> ERRO: Chocolatey nao encontrado para instalar $appName.`r`n`r`n"
                        $summary.Failed.Add([PSCustomObject]@{ Id = $appId; Nome = $appName; Code = -1 })
                        continue
                    }
                }

                # Execucao real do Chocolatey com passagem de argumentos protegida
                $argList = @("install", $appId, "-y", "--no-progress")
                if ($simular) {
                    $argList += "--noop"
                }
                if ($state.IgnoreChecksums) {
                    $argList += "--ignore-checksums"
                }

                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = $chocoExe
                $psi.Arguments = $argList -join " "
                $psi.UseShellExecute = $false
                $psi.RedirectStandardOutput = $true
                $psi.RedirectStandardError = $true
                $psi.CreateNoWindow = $true
                $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
                $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

                $proc = New-Object System.Diagnostics.Process
                $proc.StartInfo = $psi

                $outputBuffer = [System.Text.StringBuilder]::new()

                try {
                    [void]$proc.Start()

                    while (-not $proc.HasExited) {
                        $line = $proc.StandardOutput.ReadLine()
                        if ($line) {
                            [void]$outputBuffer.AppendLine($line)
                            Send-QueueLog "  | $line`r`n"
                        }
                    }
                    $remaining = $proc.StandardOutput.ReadToEnd()
                    if ($remaining) {
                        [void]$outputBuffer.Append($remaining)
                        Send-QueueLog "$remaining`r`n"
                    }

                    $errRemaining = $proc.StandardError.ReadToEnd()
                    if ($errRemaining) {
                        Send-QueueLog "  [STDERR] $errRemaining`r`n"
                    }

                    $exitCode = $proc.ExitCode
                    $capturedText = $outputBuffer.ToString()

                    # Avaliacao do resultado
                    if ($exitCode -eq 0) {
                        if ($capturedText -match "already installed" -or $capturedText -match "is already installed") {
                            Send-QueueAppStatus $appId "Ja instalado"
                            Send-QueueLog "  -> $appName ja estava instalado no sistema.`r`n`r`n"
                            $summary.AlreadyInstalled.Add([PSCustomObject]@{ Id = $appId; Nome = $appName })
                        }
                        else {
                            $statusLabel = if ($simular) { "Sucesso (Simulado)" } else { "Sucesso" }
                            Send-QueueAppStatus $appId $statusLabel
                            Send-QueueLog "  -> $appName instalado com sucesso! (Codigo: 0)`r`n`r`n"
                            $summary.Installed.Add([PSCustomObject]@{ Id = $appId; Nome = $appName })
                        }
                    }
                    elseif ($exitCode -eq 1641 -or $exitCode -eq 3010) {
                        Send-QueueAppStatus $appId "Requer reinicializacao"
                        Send-QueueLog "  -> $appName instalado com sucesso, mas requer reinicializacao do sistema. (Codigo: $exitCode)`r`n`r`n"
                        $summary.RebootRequired.Add([PSCustomObject]@{ Id = $appId; Nome = $appName; Code = $exitCode })
                    }
                    else {
                        Send-QueueAppStatus $appId "Falhou"
                        Send-QueueLog "  -> ERRO na instalacao de $appName! (Codigo de saida: $exitCode)`r`n`r`n"
                        $summary.Failed.Add([PSCustomObject]@{ Id = $appId; Nome = $appName; Code = $exitCode })
                    }
                }
                catch {
                    Send-QueueAppStatus $appId "Falhou"
                    Send-QueueLog "  -> Excecao ao executar ${appId}: $($_.Exception.Message)`r`n`r`n"
                    $summary.Failed.Add([PSCustomObject]@{ Id = $appId; Nome = $appName; Code = -1 })
                }
                finally {
                    if ($proc) { $proc.Dispose() }
                }
            }

            Send-QueueProgress 100 "Concluido $total de $total aplicativos."
        }
        # ----------------------------------------------------------------------
        # ACAO: Atualizar Tudo (choco upgrade all -y)
        # ----------------------------------------------------------------------
        elseif ($state.ActionType -eq "UpgradeAll") {
            Send-QueueLog "================================================================================`r`n"
            Send-QueueLog "Iniciando verificacao de atualizacoes de todos os pacotes (choco upgrade all)...`r`n"
            if ($simular) {
                Send-QueueLog "[MODO SIMULACAO ATIVO] Nenhuma alteracao real sera realizada (--noop).`r`n"
            }
            Send-QueueLog "================================================================================`r`n`r`n"

            Send-QueueProgress 50 "Atualizando todos os pacotes..."

            if ((-not $chocoExe -or -not (Test-Path $chocoExe)) -and $simular) {
                Start-Sleep -Seconds 1
                Send-QueueLog "  | [SIMULADO] choco upgrade all -y --noop`r`n"
                Send-QueueLog "  | Chocolatey v2.0.0 (simulado)`r`n"
                Send-QueueLog "  | Chocolatey has determined all packages are up to date (Simulated).`r`n"
                Send-QueueLog "`r`n-> Atualizacao geral simulada com sucesso!`r`n"
            }
            else {
                $argList = @("upgrade", "all", "-y")
                if ($simular) { $argList += "--noop" }
                if ($state.IgnoreChecksums) { $argList += "--ignore-checksums" }

                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = $chocoExe
                $psi.Arguments = $argList -join " "
                $psi.UseShellExecute = $false
                $psi.RedirectStandardOutput = $true
                $psi.RedirectStandardError = $true
                $psi.CreateNoWindow = $true
                $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
                $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

                $proc = New-Object System.Diagnostics.Process
                $proc.StartInfo = $psi

                try {
                    [void]$proc.Start()
                    while (-not $proc.HasExited) {
                        $line = $proc.StandardOutput.ReadLine()
                        if ($line) { Send-QueueLog "  | $line`r`n" }
                    }
                    $remaining = $proc.StandardOutput.ReadToEnd()
                    if ($remaining) { Send-QueueLog "$remaining`r`n" }

                    $exitCode = $proc.ExitCode
                    if ($exitCode -eq 0) {
                        Send-QueueLog "`r`n-> Atualizacao concluida com sucesso! (Codigo: 0)`r`n"
                    }
                    elseif ($exitCode -eq 1641 -or $exitCode -eq 3010) {
                        Send-QueueLog "`r`n-> Atualizacao concluida, mas requer reinicializacao do Windows. (Codigo: $exitCode)`r`n"
                    }
                    else {
                        Send-QueueLog "`r`n-> Atualizacao finalizada com avisos ou erros. (Codigo: $exitCode)`r`n"
                    }
                }
                catch {
                    Send-QueueLog "`r`n-> Falha ao executar atualizacao geral: $($_.Exception.Message)`r`n"
                }
                finally {
                    if ($proc) { $proc.Dispose() }
                }
            }

            Send-QueueProgress 100 "Atualizacao geral concluida."
        }

        # Notificar conclusao
        $state.Queue.Enqueue([PSCustomObject]@{
            Type    = "Complete"
            Summary = $summary
        })
    }

    function Start-ExecutionThread {
        param(
            [string]$ActionType,
            [array]$AppsToRun
        )

        if ($syncHash.IsRunning) {
            [System.Windows.Forms.MessageBox]::Show(
                "Ja existe uma operacao em andamento. Aguarde a conclusao.",
                "Pacotão",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
            return
        }

        # Desabilitar controles durante execucao
        $btnInstall.Enabled = $false
        $btnUpgradeAll.Enabled = $false
        $btnSelectAll.Enabled = $false
        $btnDeselectAll.Enabled = $false
        $btnSelectDefault.Enabled = $false
        $chkSimulation.Enabled = $false
        $chkIgnoreChecksums.Enabled = $false
        $txtSearch.Enabled = $false
        $btnRetryFailed.Visible = $false

        $syncHash.IsRunning = $true
        $syncHash.CancelRequested = $false
        $syncHash.ActionType = $ActionType
        $syncHash.AppsQueue = $AppsToRun
        $syncHash.SimulationMode = $chkSimulation.Checked
        $syncHash.IgnoreChecksums = $chkIgnoreChecksums.Checked
        $syncHash.ChocoExecutable = Get-ChocoPath
        $syncHash.CapturedLogs.Clear() | Out-Null

        # Limpar fila residual
        $dummy = $null
        while ($syncHash.Queue.TryDequeue([ref]$dummy)) {}

        # Criar Runspace isolado em segundo plano
        $runspace = [runspacefactory]::CreateRunspace()
        $runspace.ApartmentState = [System.Threading.ApartmentState]::STA
        $runspace.ThreadOptions = [System.Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
        $runspace.Open()

        $powershell = [powershell]::Create()
        $powershell.Runspace = $runspace
        [void]$powershell.AddScript($workerScriptBlock)
        [void]$powershell.AddArgument($syncHash)

        $asyncResult = $powershell.BeginInvoke()
        $uiTimer.Start()
    }

    # Acao do botao Instalar Selecionados
    $btnInstall.add_Click({
        $selectedApps = @()
        foreach ($app in $catalog) {
            if ($appSelection[$app.id]) {
                $selectedApps += $app
            }
        }

        if ($selectedApps.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show(
                "Nenhum aplicativo foi selecionado!`nPor favor, marque pelo menos um aplicativo antes de iniciar.",
                "Pacotão - Nenhum Item Selecionado",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
            return
        }

        foreach ($app in $selectedApps) {
            $appStatus[$app.id] = "Pendente"
        }
        Refresh-ListView -Filter $txtSearch.Text

        $progressBar.Value = 0
        $lblProgress.Text = "Iniciando instalacao de $($selectedApps.Count) aplicativo(s)..."

        Start-ExecutionThread -ActionType "Install" -AppsToRun $selectedApps
    })

    # Acao do botao Atualizar Tudo
    $btnUpgradeAll.add_Click({
        $simText = if ($chkSimulation.Checked) { " (Modo SIMULACAO ativo)" } else { "" }
        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "Deseja verificar e atualizar TODOS os pacotes instalados pelo Chocolatey$simText?`n`nComando: choco upgrade all -y`nIsso pode levar alguns minutos.",
            "Pacotão - Confirmar Atualizacao Geral",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )

        if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
            $progressBar.Value = 0
            $lblProgress.Text = "Iniciando atualizacao de todos os pacotes..."
            Start-ExecutionThread -ActionType "UpgradeAll" -AppsToRun @()
        }
    })

    # Inicializar dados e exibir janela
    Refresh-ListView
    [void]$form.ShowDialog()

    # Liberar recursos ao fechar
    $uiTimer.Stop()
    $uiTimer.Dispose()
    $form.Dispose()

    # Restaurar console caso o usuario tenha aberto a partir de um terminal interativo
    if ($script:consoleHandle -and $script:consoleHandle -ne [IntPtr]::Zero) {
        try {
            [void][PacotaoWin32.Win32ConsoleHelper]::ShowWindow($script:consoleHandle, 5) # 5 = SW_SHOW
        } catch {}
    }
}

# Iniciar aplicacao
if (-not $NoGui) {
    Show-PacotaoMainWindow
}
