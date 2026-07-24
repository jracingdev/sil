// Launcher WinExe do instalador visual S.I.L.
// Compilar: ..\Build-Exe.ps1
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;
using System.Windows.Forms;

internal static class Program
{
    [STAThread]
    private static int Main(string[] args)
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        try
        {
            string dir = AppDirectory();
            string ps1 = Path.Combine(dir, "Abrir-Instalador.ps1");
            if (!File.Exists(ps1))
            {
                MessageBox.Show(
                    "Nao encontrei Abrir-Instalador.ps1 na pasta do instalador.\r\n\r\n" +
                    "Pasta esperada:\r\n" + dir + "\r\n\r\n" +
                    "Mantenha SIL-Instalador.exe junto com os arquivos .ps1.",
                    "S.I.L. - Instalador",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
                return 1;
            }

            string engine = Path.Combine(dir, "SilEngine.ps1");
            if (!File.Exists(engine))
            {
                MessageBox.Show(
                    "Nao encontrei SilEngine.ps1.\r\n\r\nPasta:\r\n" + dir,
                    "S.I.L. - Instalador",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
                return 1;
            }

            var argBuilder = new StringBuilder();
            argBuilder.Append("-NoProfile -ExecutionPolicy Bypass -STA -File \"");
            argBuilder.Append(ps1);
            argBuilder.Append("\"");

            // Encaminha -Config se passado ao .exe
            for (int i = 0; i < args.Length; i++)
            {
                if (string.Equals(args[i], "-Config", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length)
                {
                    argBuilder.Append(" -Config \"");
                    argBuilder.Append(args[i + 1]);
                    argBuilder.Append("\"");
                    break;
                }
            }

            var psi = new ProcessStartInfo
            {
                FileName = ResolvePowerShell(),
                Arguments = argBuilder.ToString(),
                WorkingDirectory = dir,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            using (Process p = Process.Start(psi))
            {
                if (p == null)
                {
                    MessageBox.Show(
                        "Nao foi possivel iniciar o PowerShell.",
                        "S.I.L. - Instalador",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Error);
                    return 1;
                }
                p.WaitForExit();
                int code = p.ExitCode;
                if (code != 0)
                {
                    string errLog = Path.Combine(dir, "instalador_erro.txt");
                    string detail = File.Exists(errLog)
                        ? ("\r\n\r\nDetalhes:\r\n" + File.ReadAllText(errLog, Encoding.UTF8))
                        : string.Empty;
                    MessageBox.Show(
                        "O instalador encerrou com codigo " + code + "." + detail,
                        "S.I.L. - Instalador",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Warning);
                }
                return code;
            }
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                ex.Message,
                "S.I.L. - Erro",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
            return 1;
        }
    }

    private static string AppDirectory()
    {
        string loc = Assembly.GetExecutingAssembly().Location;
        if (string.IsNullOrEmpty(loc))
            loc = Application.ExecutablePath;
        return Path.GetFullPath(Path.GetDirectoryName(loc) ?? ".");
    }

    private static string ResolvePowerShell()
    {
        // Prefere Windows PowerShell 5.1 (WinForms/STA estavel no instalador atual)
        string sys = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.System),
            "WindowsPowerShell", "v1.0", "powershell.exe");
        if (File.Exists(sys)) return sys;
        return "powershell.exe";
    }
}
