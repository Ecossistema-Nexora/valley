using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Text;

internal static class ValleyWindowsInstaller
{
    private const string ResourceName = "ValleyBundle.zip";

    [STAThread]
    private static int Main(string[] args)
    {
        try
        {
            bool noLaunch = HasArg(args, "-NoLaunch") || HasArg(args, "/NoLaunch");
            Install(noLaunch);
            return 0;
        }
        catch (Exception ex)
        {
            TryWriteFailure(ex);
            return 1;
        }
    }

    private static void Install(bool noLaunch)
    {
        string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        string appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        string valleyRoot = Path.Combine(localAppData, "Valley");
        string installRoot = Path.Combine(valleyRoot, "ValleySuperApp");
        string safeBase = Path.GetFullPath(valleyRoot);
        string safeTarget = Path.GetFullPath(installRoot);

        if (!safeTarget.StartsWith(safeBase, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException("Invalid install target: " + safeTarget);
        }

        Directory.CreateDirectory(installRoot);
        ClearDirectory(installRoot);

        string tempZip = Path.Combine(Path.GetTempPath(), "valley_super_app_windows_bundle_" + Guid.NewGuid().ToString("N") + ".zip");
        try
        {
            ExtractEmbeddedBundle(tempZip);
            ZipFile.ExtractToDirectory(tempZip, installRoot);
        }
        finally
        {
            TryDeleteFile(tempZip);
        }

        string exePath = Path.Combine(installRoot, "valley_super_app.exe");
        if (!File.Exists(exePath))
        {
            throw new FileNotFoundException("Valley executable was not extracted.", exePath);
        }

        string startMenuShortcut = Path.Combine(appData, @"Microsoft\Windows\Start Menu\Programs\Valley\Valley.lnk");
        string startupShortcut = Path.Combine(appData, @"Microsoft\Windows\Start Menu\Programs\Startup\Valley.lnk");
        string taskbarShortcut = Path.Combine(appData, @"Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Valley.lnk");

        CreateShortcut(startMenuShortcut, exePath, installRoot);
        CreateShortcut(startupShortcut, exePath, installRoot);
        CreateShortcut(taskbarShortcut, exePath, installRoot);

        bool taskbarPinned = TryPinToTaskbar(startMenuShortcut);

        string statusPath = Path.Combine(installRoot, "install-status.json");
        File.WriteAllText(statusPath, BuildStatusJson(installRoot, exePath, startMenuShortcut, startupShortcut, taskbarShortcut, taskbarPinned, !noLaunch), Encoding.UTF8);

        if (!noLaunch)
        {
            ProcessStartInfo startInfo = new ProcessStartInfo
            {
                FileName = exePath,
                WorkingDirectory = installRoot,
                UseShellExecute = true
            };
            Process.Start(startInfo);
        }
    }

    private static bool HasArg(string[] args, string value)
    {
        foreach (string arg in args)
        {
            if (string.Equals(arg, value, StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }
        }
        return false;
    }

    private static void ExtractEmbeddedBundle(string targetZip)
    {
        Assembly assembly = Assembly.GetExecutingAssembly();
        using (Stream input = assembly.GetManifestResourceStream(ResourceName))
        {
            if (input == null)
            {
                throw new InvalidOperationException("Embedded resource not found: " + ResourceName);
            }
            using (FileStream output = File.Create(targetZip))
            {
                input.CopyTo(output);
            }
        }
    }

    private static void ClearDirectory(string path)
    {
        foreach (string file in Directory.GetFiles(path))
        {
            File.SetAttributes(file, FileAttributes.Normal);
            File.Delete(file);
        }

        foreach (string directory in Directory.GetDirectories(path))
        {
            Directory.Delete(directory, true);
        }
    }

    private static void CreateShortcut(string shortcutPath, string targetPath, string workingDirectory)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(shortcutPath));

        Type shellType = Type.GetTypeFromProgID("WScript.Shell");
        if (shellType == null)
        {
            throw new InvalidOperationException("WScript.Shell COM object is unavailable.");
        }

        dynamic shell = Activator.CreateInstance(shellType);
        dynamic shortcut = shell.CreateShortcut(shortcutPath);
        shortcut.TargetPath = targetPath;
        shortcut.WorkingDirectory = workingDirectory;
        shortcut.IconLocation = targetPath + ",0";
        shortcut.Description = "Valley";
        shortcut.Save();
    }

    private static bool TryPinToTaskbar(string shortcutPath)
    {
        try
        {
            Type shellType = Type.GetTypeFromProgID("Shell.Application");
            if (shellType == null)
            {
                return false;
            }

            dynamic shell = Activator.CreateInstance(shellType);
            dynamic folder = shell.Namespace(Path.GetDirectoryName(shortcutPath));
            if (folder == null)
            {
                return false;
            }

            dynamic item = folder.ParseName(Path.GetFileName(shortcutPath));
            if (item == null)
            {
                return false;
            }

            foreach (dynamic verb in item.Verbs())
            {
                string name = Convert.ToString(verb.Name).Replace("&", string.Empty).Trim();
                if (name.IndexOf("Pin to taskbar", StringComparison.OrdinalIgnoreCase) >= 0 ||
                    name.IndexOf("Fixar na barra de tarefas", StringComparison.OrdinalIgnoreCase) >= 0 ||
                    name.IndexOf("Fixar na Barra de Tarefas", StringComparison.OrdinalIgnoreCase) >= 0 ||
                    name.IndexOf("Fixar na barra", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    verb.DoIt();
                    return true;
                }
            }
        }
        catch
        {
            return false;
        }

        return false;
    }

    private static string BuildStatusJson(
        string installRoot,
        string exePath,
        string startMenuShortcut,
        string startupShortcut,
        string taskbarShortcut,
        bool taskbarPinned,
        bool launchRequested)
    {
        StringBuilder json = new StringBuilder();
        json.AppendLine("{");
        AppendJson(json, "installed_at", DateTimeOffset.Now.ToString("o"), true);
        AppendJson(json, "app_name", "Valley", true);
        AppendJson(json, "install_root", installRoot, true);
        AppendJson(json, "exe_path", exePath, true);
        AppendJson(json, "start_menu_shortcut", startMenuShortcut, true);
        AppendJson(json, "startup_shortcut", startupShortcut, true);
        AppendJson(json, "taskbar_shortcut", taskbarShortcut, true);
        json.AppendLine("  \"taskbar_pin_attempted\": true,");
        json.AppendLine("  \"taskbar_pin_confirmed_by_shell_verb\": " + (taskbarPinned ? "true" : "false") + ",");
        json.AppendLine("  \"launch_requested\": " + (launchRequested ? "true" : "false"));
        json.AppendLine("}");
        return json.ToString();
    }

    private static void AppendJson(StringBuilder json, string key, string value, bool comma)
    {
        json.Append("  \"").Append(EscapeJson(key)).Append("\": \"").Append(EscapeJson(value)).Append("\"");
        if (comma)
        {
            json.Append(",");
        }
        json.AppendLine();
    }

    private static string EscapeJson(string value)
    {
        return value.Replace("\\", "\\\\").Replace("\"", "\\\"");
    }

    private static void TryDeleteFile(string path)
    {
        try
        {
            if (File.Exists(path))
            {
                File.Delete(path);
            }
        }
        catch
        {
        }
    }

    private static void TryWriteFailure(Exception ex)
    {
        try
        {
            string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            string logDir = Path.Combine(localAppData, "Valley", "ValleySuperApp");
            Directory.CreateDirectory(logDir);
            File.WriteAllText(Path.Combine(logDir, "install-error.log"), ex.ToString(), Encoding.UTF8);
        }
        catch
        {
        }
    }
}

