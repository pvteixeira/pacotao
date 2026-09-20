# 🚀 Pacotão - Instalador em Lote para Windows

[![GitHub Repository](https://img.shields.io/badge/GitHub-pvteixeira%2Fpacotao-181717?logo=github&logoColor=white)](https://github.com/pvteixeira/pacotao)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Open Source Love](https://badges.frapsoft.com/os/v1/open-source.svg?v=103)](https://github.com/pvteixeira/pacotao)
![Windows 10/11](https://img.shields.io/badge/Windows-10%20%7C%2011%20(64--bit)-0078D6?logo=windows&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B%20Nativo-5391FE?logo=powershell&logoColor=white)
![Chocolatey](https://img.shields.io/badge/Chocolatey-Package%20Manager-80B5EA?logo=chocolatey&logoColor=white)
![Build](https://img.shields.io/badge/Build-Standalone%20100%25-success?logo=windows)
![Interface](https://img.shields.io/badge/GUI-Windows%20Forms%20(Dark%20%2F%20Modern)-2ea44f)

O **Pacotão** é uma ferramenta **Open-Source** para técnicos de suporte e administradores de TI. Ele automatiza a seleção, o download e a instalação sequencial de aplicativos essenciais, navegadores, utilitários, drivers e softwares para certificados digitais através do **Chocolatey** e de instaladores oficiais diretos.

---

## 📁 Estrutura do Projeto

O repositório e a pasta de distribuição foram organizados de forma limpa e modular:

```text
d:\Install_app\
├── 🚀 Pacotao.exe       # Executável único standalone (com motor embutido e UAC nativo)
├── 📋 apps.json         # Catálogo personalizável de softwares e drivers (31 itens)
├── 📖 README.md         # Documentação e manual de uso
├── 📜 LICENSE           # Licença Open-Source (MIT)
├── 🤝 CONTRIBUTING.md   # Guia de contribuição da comunidade
├── 🙈 .gitignore        # Arquivos ignorados pelo Git
├── 📂 .github/          # Modelos de Issues para sugestão de programas e relatos de bugs
└── 📂 src/              # Código-fonte completo para auditoria e desenvolvimento
    ├── ⚙️ Pacotao.ps1   # Motor da aplicação em PowerShell 5.1 e Windows Forms
    ├── 🖥️ Launcher.cs   # Inicializador nativo C# (.NET Framework)
    └── 🛡️ app.manifest  # Manifesto do Windows com elevação administrativa UAC
```

> [!TIP]
> ### 💡 Executável 100% Standalone
> Para usar no dia a dia em computadores de clientes ou na bancada técnica, você só precisa copiar **`Pacotao.exe`** e **`apps.json`** para um pendrive! O executável já contém todo o motor da aplicação embutido internamente.

---

## ⚡ Como Usar

### 1. Início Rápido
1. Dê um **duplo clique** em **`Pacotao.exe`**.
2. Clique em **"Sim"** no prompt de Administrador do Windows (UAC).
3. A interface gráfica moderna abrirá imediatamente com as ferramentas essenciais já pré-selecionadas.

### 2. Seleção e Instalação
- **Filtro em Tempo Real:** Digite o nome ou ID de qualquer programa na barra de pesquisa (o filtro mantém marcados os itens selecionados).
- **Botões de Atalho:**
  - **Padrão:** Seleciona a configuração recomendada de programas essenciais para formatações.
  - **Marcar Todos / Desmarcar Todos:** Seleciona ou desmarca toda a lista com 1 clique.
- **Apenas Simular (`--noop`):** Teste toda a rotina do Chocolatey sem fazer qualquer instalação real no sistema.
- Clique no botão verde **"Instalar Selecionados"** para iniciar a instalação automatizada e acompanhar o progresso e os logs na tela.

---

## ✨ Recursos e Diferenciais

- 🛡️ **Auto-Elevação UAC Nativa:** O executável solicita diretamente permissão de Administrador ao Windows, sem exibir janelas pretas de terminal.
- 🍫 **Automação Completa do Chocolatey:** Detecta automaticamente se o Chocolatey está presente. Caso não esteja, oferece a instalação oficial imediata com 1 clique.
- 🔄 **Instalação Estritamente Sequencial:** Instala um pacote por vez, evitando concorrência de disco e erros de `msiexec.exe`.
- 🧵 **Multithreading via Runspaces:** Todo o processo de download e instalação roda em segundo plano. A interface nunca trava e a barra de progresso flui perfeitamente.
- 📝 **Gravação Automática de Logs:** Salva relatórios detalhados em `%USERPROFILE%\Pacotao\logs\pacotao_YYYY-MM-DD_HH-mm-ss.log` com botão direto para **"Abrir Pasta de Logs"**.
- 🔁 **Recuperação de Falhas:** Botão dedicado para **"Tentar Novamente os que Falharam"** que reprocessa apenas os softwares que apresentaram erro.
- 🆙 **Atualização Geral:** Botão **"Atualizar Tudo"** (`choco upgrade all -y`) para atualizar os programas já instalados no computador.

---

## 📦 Catálogo Pré-Configurado (31 Aplicativos e Drivers)

O catálogo [`apps.json`](file:///d:/Install_app/apps.json) vem configurado com **31 itens essenciais** organizados em 9 categorias:

| Categoria | Aplicativo / Pacote | Padrão | Método |
| :--- | :--- | :---: | :--- |
| **🔐 Certificado Digital** | Certisign DesktopID (A1/A3) | Não | Download Oficial Direto |
| | Driver Token ePass 2003 (Feitian/Certisign) | Não | Download Oficial Direto |
| | Gerenciador Token SafeSign (GD StarSign 64-bit) | Não | Download Oficial Direto |
| | Gerenciador Token SafeNet 5110 (SAC 10.6 64-bit) | Não | Download Oficial Direto |
| | **Java Runtime Environment 8 (JRE 8)** *(Conectividade / PJe / e-CAC)* | **Sim** | Chocolatey (`jre8`) |
| **🌐 Navegadores** | **Google Chrome** | **Sim** | Chocolatey (`googlechrome`) |
| | Mozilla Firefox | Não | Chocolatey (`firefox`) |
| | Brave Browser | Não | Chocolatey (`brave`) |
| | Opera GX (Gaming Browser) | Não | Chocolatey (`opera-gx`) |
| **🖥️ Acesso Remoto** | **AnyDesk** | **Sim** | Chocolatey (`anydesk.install`) |
| | TeamViewer | Não | Chocolatey (`teamviewer`) |
| **📄 Documentos e PDF** | **Adobe Acrobat Reader DC** | **Sim** | Chocolatey (`adobereader`) |
| | LibreOffice (Suíte Office gratuita) | Não | Chocolatey (`libreoffice-fresh`) |
| **🧰 Utilitários** | **7-Zip** | **Sim** | Chocolatey (`7zip`) |
| | WinRAR | Não | Chocolatey (`winrar`) |
| | **Notepad++** | **Sim** | Chocolatey (`notepadplusplus`) |
| | Lightshot (Captura de tela ágil) | Não | Chocolatey (`lightshot`) |
| | Microsoft PowerToys | Não | Chocolatey (`powertoys`) |
| **💬 Comunicação** | **WhatsApp Desktop** | **Sim** | Chocolatey (`whatsapp`) |
| | Telegram Desktop | Não | Chocolatey (`telegram`) |
| | **Discord** | **Sim** | Chocolatey (`discord`) |
| | Zoom Meetings | Não | Chocolatey (`zoom`) |
| **🎬 Mídia** | **VLC Media Player** | **Sim** | Chocolatey (`vlc`) |
| | **Spotify** | **Sim** | Chocolatey (`spotify`) |
| | OBS Studio | Não | Chocolatey (`obs-studio`) |
| **💻 Desenvolvimento** | **Visual Studio Code** | **Sim** | Chocolatey (`vscode`) |
| | **Git for Windows** | **Sim** | Chocolatey (`git`) |
| | Node.js (LTS) | Não | Chocolatey (`nodejs-lts`) |
| | Python 3 | Não | Chocolatey (`python`) |
| | Postman | Não | Chocolatey (`postman`) |
| **🎮 Jogos** | Steam | Não | Chocolatey (`steam`) |

---

## 🛠️ Como Adicionar Novos Programas no `apps.json`

Você pode personalizar a lista de programas a qualquer momento apenas editando o arquivo [`apps.json`](file:///d:/Install_app/apps.json) em qualquer editor de texto. Não precisa recompilar o executável!

### 1. Pacote do Chocolatey (Padrão)
1. Pesquise o ID oficial em: [community.chocolatey.org/packages](https://community.chocolatey.org/packages)
2. Adicione ao `apps.json`:
```json
{
  "id": "dbeaver",
  "nome": "DBeaver Community Edition",
  "categoria": "Desenvolvimento",
  "padrao": false
}
```

### 2. Instalador ou Driver com Download Direto (.exe)
Para programas proprietários ou instaladores específicos:
```json
{
  "id": "meu-driver",
  "nome": "Driver Específico",
  "categoria": "Utilitários",
  "padrao": false,
  "url": "https://exemplo.com/instalador.exe",
  "argumentos": "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART"
}
```

> [!IMPORTANT]
> **Segurança:** O campo `id` aceita estritamente letras, números, pontos, hifens e sublinhados (`^[a-zA-Z0-9\.\-_]+$`), bloqueando caracteres especiais ou injeções de comando.

---

## ⚙️ Como Recompilar o Executável (Desenvolvedores)

Se você editar o código em `src/Pacotao.ps1` ou `src/Launcher.cs` e quiser gerar um novo `Pacotao.exe` standalone:

```powershell
& 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe' /nologo /target:winexe /optimize+ `
    /win32manifest:'src\app.manifest' `
    /resource:'src\Pacotao.ps1,Pacotao.ps1' `
    /out:'Pacotao.exe' `
    'src\Launcher.cs'
```

---

## 🤝 Como Contribuir

Contribuições da comunidade são muito bem-vindas! Você pode sugerir novos aplicativos, reportar problemas ou propor melhorias de código.

Consulte o nosso **[Guia de Contribuição (CONTRIBUTING.md)](CONTRIBUTING.md)** para instruções passo a passo sobre como enviar um Pull Request.

---

## 📄 Licença

Este projeto é de código aberto e está licenciado sob a **[Licença MIT](LICENSE)**. Você é livre para utilizar, modificar e distribuir conforme desejar.

---

## 👤 Autor

Desenvolvido por **Pedro Victor Teixeira** ([@pvteixeira](https://github.com/pvteixeira)).
Se este projeto foi útil para você, deixe uma ⭐ no repositório!
