using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

namespace PacotaoLauncher
{
    static class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            try
            {
                string baseDir = AppDomain.CurrentDomain.BaseDirectory;
                string scriptPath = Path.Combine(baseDir, "Pacotao.ps1");

                // 1. Se existir Pacotao.ps1 local na pasta, usa ele (permite testes e customizações).
                // 2. Caso contrário, extrai a engine embutida do executável para %TEMP%\Pacotao.
                if (!File.Exists(scriptPath))
                {
                    Assembly assembly = Assembly.GetExecutingAssembly();
                    Stream stream = assembly.GetManifestResourceStream("Pacotao.ps1");

                    if (stream == null)
                    {
                        foreach (string res in assembly.GetManifestResourceNames())
                        {
                            if (res.EndsWith("Pacotao.ps1", StringComparison.OrdinalIgnoreCase))
                            {
                                stream = assembly.GetManifestResourceStream(res);
                                break;
                            }
                        }
                    }

                    if (stream == null)
                    {
                        MessageBox.Show(
                            "O motor interno do Pacotão não foi localizado dentro deste executável.",
                            "Pacotão - Erro Crítico",
                            MessageBoxButtons.OK,
                            MessageBoxIcon.Error
                        );
                        return;
                    }

                    using (stream)
                    {
                        string tempDir = Path.Combine(Path.GetTempPath(), "Pacotao");
                        if (!Directory.Exists(tempDir))
                        {
                            Directory.CreateDirectory(tempDir);
                        }

                        scriptPath = Path.Combine(tempDir, "Pacotao_engine.ps1");

                        using (FileStream fs = new FileStream(scriptPath, FileMode.Create, FileAccess.Write, FileShare.None))
                        {
                            byte[] buffer = new byte[81920];
                            int bytesRead;
                            while ((bytesRead = stream.Read(buffer, 0, buffer.Length)) > 0)
                            {
                                fs.Write(buffer, 0, bytesRead);
                            }
                        }
                    }
                }

                // Verificação de existência do apps.json na pasta da aplicação
                string catalogPath = Path.Combine(baseDir, "apps.json");
                if (!File.Exists(catalogPath))
                {
                    DialogResult dr = MessageBox.Show(
                        "O catálogo de aplicativos 'apps.json' não foi encontrado na mesma pasta do executável!\n\n" +
                        "Caminho esperado:\n" + catalogPath + "\n\n" +
                        "Deseja iniciar o Pacotão mesmo assim?",
                        "Pacotão - apps.json Não Encontrado",
                        MessageBoxButtons.YesNo,
                        MessageBoxIcon.Warning
                    );

                    if (dr != DialogResult.Yes)
                    {
                        return;
                    }
                }

                string extraArgs = string.Join(" ", args);
                string psArguments = "-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File \"" + scriptPath + "\"";
                if (!string.IsNullOrEmpty(extraArgs))
                {
                    psArguments += " " + extraArgs;
                }

                ProcessStartInfo psi = new ProcessStartInfo();
                psi.FileName = "powershell.exe";
                psi.Arguments = psArguments;
                psi.WorkingDirectory = baseDir;
                psi.EnvironmentVariables["PACOTAO_APP_DIR"] = baseDir;
                psi.WindowStyle = ProcessWindowStyle.Hidden;
                psi.CreateNoWindow = true;
                psi.UseShellExecute = false;

                Process.Start(psi);
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    "Erro ao iniciar o Pacotão:\n\n" + ex.Message,
                    "Pacotão - Erro de Inicialização",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error
                );
            }
        }
    }
}
