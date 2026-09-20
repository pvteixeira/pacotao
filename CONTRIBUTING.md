# 🤝 Guia de Contribuição - Pacotão

Ficamos muito felizes pelo seu interesse em contribuir com o **Pacotão**! Este é um projeto **Open-Source** mantido pela comunidade e para a comunidade.

---

## 💡 Formas de Contribuir

Você pode contribuir de diversas maneiras:
1. **Adicionando novos softwares ao catálogo (`apps.json`)**.
2. **Reportando bugs** ou comportamentos inesperados em versões específicas do Windows.
3. **Melhorando a interface gráfica** ou adicionando novos recursos no motor em PowerShell / C#.
4. **Melhorando a documentação** e instruções de uso.

---

## 📦 Adicionando um Novo Aplicativo ao `apps.json`

A forma mais comum de contribuição é sugerir novos aplicativos essenciais para o catálogo:

1. Verifique se o aplicativo é amplamente utilizado e confiável.
2. Se for um pacote do **Chocolatey**:
   - Localize o ID oficial em [community.chocolatey.org/packages](https://community.chocolatey.org/packages).
   - Teste localmente usando o modo de simulação (`--noop`) ou instalação real.
3. Se for um **instalador com download direto** (ex: drivers proprietários de tokens ou impressoras):
   - Deve ser obrigatoriamente um link direto oficial **HTTPS** do fabricante.
   - Deve conter argumentos de instalação totalmente silenciosa (ex.: `/VERYSILENT /SUPPRESSMSGBOXES /NORESTART` ou `/s /v"/qn"`).
4. O campo `id` aceita estritamente letras, números, pontos, hifens e sublinhados (`^[a-zA-Z0-9\.\-_]+$`).

Exemplo:
```json
{
  "id": "7zip",
  "nome": "7-Zip",
  "categoria": "Utilitários",
  "padrao": true
}
```

---

## 💻 Fluxo de Trabalho com o Git

1. **Faça um Fork** deste repositório para o seu perfil no GitHub.
2. **Clone** o seu fork para a sua máquina:
   ```bash
   git clone https://github.com/SEU_USUARIO/pacotao.git
   cd pacotao
   ```
3. **Crie uma branch** descritiva para a sua alteração:
   ```bash
   git checkout -b feature/adicionar-dbeaver
   ```
4. **Faça suas alterações** e valide localmente:
   - Se alterou o script em `src/Pacotao.ps1`, teste a sintaxe com o parser do PowerShell.
   - Se alterou o `apps.json`, verifique se o JSON continua válido (`ConvertFrom-Json`).
5. **Faça o commit** das suas alterações:
   ```bash
   git add .
   git commit -m "feat(catalogo): adiciona DBeaver na categoria Desenvolvimento"
   ```
6. **Envie para o seu GitHub**:
   ```bash
   git push origin feature/adicionar-dbeaver
   ```
7. **Abra um Pull Request (PR)** explicando a motivação da alteração.

---

## 🛠️ Recompilando o Executável

Se você alterou arquivos em `src/` e deseja gerar um novo `Pacotao.exe`:

```powershell
& 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe' /nologo /target:winexe /optimize+ `
    /win32manifest:'src\app.manifest' `
    /resource:'src\Pacotao.ps1,Pacotao.ps1' `
    /out:'Pacotao.exe' `
    'src\Launcher.cs'
```

---

## 📜 Licença

Ao contribuir com este projeto, você concorda que suas contribuições serão licenciadas sob os termos da [Licença MIT](LICENSE).
