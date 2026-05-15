using System.Diagnostics;
using System.IO.Compression;
using System.Reflection;
using System.Text.Json;
using Microsoft.Win32;

const string ResourceName = "valley-erp-payload.zip";
const string AppFolderName = "ValleyERP-Lojista";
const string PackageFolderName = "ValleyERP-Lojista-Windows-x64";
const string AppExeRelativePath = "app/ValleyERP-Lojista.exe";
const string ApiBaseUrl = "https://admin.brasildesconto.com.br";
const string StartupValueName = "Valley ERP Lojista";

static bool HasArg(string[] args, string name)
{
    return args.Any(arg => string.Equals(arg, name, StringComparison.OrdinalIgnoreCase));
}

static string RequireWindowsLocalAppData()
{
    string? localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
    if (string.IsNullOrWhiteSpace(localAppData))
    {
        throw new InvalidOperationException("LOCALAPPDATA nao encontrado para instalar o Valley ERP.");
    }
    return localAppData;
}

static string NewReleaseId()
{
    return DateTime.UtcNow.ToString("yyyyMMddHHmmss") + "-" + Environment.ProcessId;
}

static void DeleteDirectoryIfExists(string path)
{
    if (Directory.Exists(path))
    {
        Directory.Delete(path, recursive: true);
    }
}

static void CleanDirectory(string path)
{
    DeleteDirectoryIfExists(path);
    Directory.CreateDirectory(path);
}

static void ExtractPayload(string extractRoot)
{
    Directory.CreateDirectory(extractRoot);
    using Stream? payload = Assembly.GetExecutingAssembly().GetManifestResourceStream(ResourceName);
    if (payload is null)
    {
        throw new InvalidOperationException("Payload do Valley ERP nao foi embutido no executavel.");
    }

    string zipPath = Path.Combine(extractRoot, "payload.zip");
    using (FileStream zipFile = File.Create(zipPath))
    {
        payload.CopyTo(zipFile);
    }

    string extractRootFull = Path.GetFullPath(extractRoot);
    using (ZipArchive archive = ZipFile.OpenRead(zipPath))
    {
        foreach (ZipArchiveEntry entry in archive.Entries)
        {
            string destination = Path.GetFullPath(Path.Combine(extractRootFull, entry.FullName));
            if (!destination.StartsWith(extractRootFull + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase) &&
                !string.Equals(destination, extractRootFull, StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidDataException("Payload contem caminho invalido: " + entry.FullName);
            }

            if (string.IsNullOrEmpty(entry.Name))
            {
                Directory.CreateDirectory(destination);
                continue;
            }

            Directory.CreateDirectory(Path.GetDirectoryName(destination) ?? extractRootFull);
            entry.ExtractToFile(destination, overwrite: true);
        }
    }

    File.Delete(zipPath);
}

static string FindExecutable(string extractRoot)
{
    string expected = Path.Combine(extractRoot, PackageFolderName, AppExeRelativePath.Replace('/', Path.DirectorySeparatorChar));
    if (File.Exists(expected))
    {
        return expected;
    }

    string[] matches = Directory.GetFiles(extractRoot, "ValleyERP-Lojista.exe", SearchOption.AllDirectories);
    if (matches.Length == 0)
    {
        throw new FileNotFoundException("ValleyERP-Lojista.exe nao encontrado apos extracao.");
    }
    return matches[0];
}

static string ValidatePackage(string extractRoot)
{
    string appExe = FindExecutable(extractRoot);
    string appDir = Path.GetDirectoryName(appExe) ?? throw new InvalidOperationException("Diretorio do app nao encontrado.");
    string[] requiredFiles =
    [
        appExe,
        Path.Combine(appDir, "flutter_windows.dll"),
        Path.Combine(appDir, "data", "flutter_assets", "AssetManifest.bin")
    ];

    foreach (string file in requiredFiles)
    {
        if (!File.Exists(file))
        {
            throw new FileNotFoundException("Arquivo obrigatorio ausente no pacote Windows: " + file);
        }
        if (new FileInfo(file).Length <= 0)
        {
            throw new InvalidDataException("Arquivo obrigatorio vazio no pacote Windows: " + file);
        }
    }

    return appExe;
}

static string InstallPayload()
{
    string localAppData = RequireWindowsLocalAppData();
    string installBase = Path.Combine(localAppData, "Programs", AppFolderName);
    Directory.CreateDirectory(installBase);

    string releaseId = NewReleaseId();
    string stagingRoot = Path.Combine(installBase, "staging-" + releaseId);
    CleanDirectory(stagingRoot);
    ExtractPayload(stagingRoot);
    ValidatePackage(stagingRoot);

    string installRoot = Path.Combine(installBase, "current");
    try
    {
        DeleteDirectoryIfExists(installRoot);
        Directory.Move(stagingRoot, installRoot);
    }
    catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
    {
        installRoot = Path.Combine(installBase, "releases", releaseId);
        Directory.CreateDirectory(Path.GetDirectoryName(installRoot) ?? installBase);
        Directory.Move(stagingRoot, installRoot);
    }

    return ValidatePackage(installRoot);
}

static bool RegisterStartup(string appExe)
{
    string quotedExe = "\"" + appExe + "\"";
    try
    {
        using RegistryKey? runKey = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run", writable: true)
            ?? Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run", writable: true);
        runKey?.SetValue(StartupValueName, quotedExe, RegistryValueKind.String);
        return true;
    }
    catch
    {
        string startupDir = Environment.GetFolderPath(Environment.SpecialFolder.Startup);
        if (string.IsNullOrWhiteSpace(startupDir))
        {
            return false;
        }
        Directory.CreateDirectory(startupDir);
        string startupCmd = Path.Combine(startupDir, "Valley ERP Lojista.cmd");
        File.WriteAllText(startupCmd, "@echo off\r\nstart \"\" " + quotedExe + "\r\n");
        return true;
    }
}

static void RemoveStartup()
{
    try
    {
        using RegistryKey? runKey = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run", writable: true);
        runKey?.DeleteValue(StartupValueName, throwOnMissingValue: false);
    }
    catch
    {
        // Registry cleanup is best effort because startup fallback may be file-based.
    }

    string startupDir = Environment.GetFolderPath(Environment.SpecialFolder.Startup);
    if (!string.IsNullOrWhiteSpace(startupDir))
    {
        string startupCmd = Path.Combine(startupDir, "Valley ERP Lojista.cmd");
        if (File.Exists(startupCmd))
        {
            File.Delete(startupCmd);
        }
    }
}

static string FindInstalledExecutable()
{
    string installBase = Path.Combine(RequireWindowsLocalAppData(), "Programs", AppFolderName);
    string current = Path.Combine(installBase, "current");
    if (Directory.Exists(current))
    {
        return ValidatePackage(current);
    }

    string releasesRoot = Path.Combine(installBase, "releases");
    if (Directory.Exists(releasesRoot))
    {
        DirectoryInfo? latestRelease = new DirectoryInfo(releasesRoot)
            .GetDirectories()
            .OrderByDescending(directory => directory.LastWriteTimeUtc)
            .FirstOrDefault();
        if (latestRelease is not null)
        {
            return ValidatePackage(latestRelease.FullName);
        }
    }

    throw new FileNotFoundException("Instalacao local do Valley ERP nao encontrada.");
}

static void Uninstall()
{
    RemoveStartup();
    string installBase = Path.Combine(RequireWindowsLocalAppData(), "Programs", AppFolderName);
    DeleteDirectoryIfExists(installBase);
}

static void WriteInstallState(string appExe, bool startupRegistered)
{
    string appDir = Path.GetDirectoryName(appExe) ?? RequireWindowsLocalAppData();
    string statePath = Path.Combine(appDir, "valley-erp-install-state.json");
    var state = new
    {
        product = "Valley ERP Lojista",
        installed_at_utc = DateTime.UtcNow.ToString("o"),
        app_exe = appExe,
        api_base_url = ApiBaseUrl,
        startup_registered = startupRegistered,
        startup_value_name = StartupValueName,
        end_user_build = true
    };
    File.WriteAllText(statePath, JsonSerializer.Serialize(state, new JsonSerializerOptions { WriteIndented = true }));
}

static int VerifyPayloadOnly()
{
    string checkRoot = Path.Combine(Path.GetTempPath(), AppFolderName, "check-" + NewReleaseId());
    try
    {
        CleanDirectory(checkRoot);
        ExtractPayload(checkRoot);
        string appExe = ValidatePackage(checkRoot);
        Console.WriteLine("status=ok");
        Console.WriteLine("validated_exe=" + appExe);
        return 0;
    }
    finally
    {
        try
        {
            DeleteDirectoryIfExists(checkRoot);
        }
        catch
        {
            // Best effort cleanup; validation result is independent from temp cleanup.
        }
    }
}

static void LaunchApp(string appExe)
{
    ProcessStartInfo startInfo = new()
    {
        FileName = appExe,
        WorkingDirectory = Path.GetDirectoryName(appExe) ?? RequireWindowsLocalAppData(),
        UseShellExecute = false,
    };
    startInfo.Environment["VALLEY_PRODUCT_API_BASE_URL"] = ApiBaseUrl;
    startInfo.Environment["VALLEY_END_USER_BUILD"] = "true";
    Process.Start(startInfo);
}

try
{
    if (!OperatingSystem.IsWindows())
    {
        Console.Error.WriteLine("Este arquivo e o executavel Windows. Use Valley-ERP-Linux.run no Linux.");
        return 2;
    }

    if (HasArg(args, "--check") || HasArg(args, "--verify-only"))
    {
        return VerifyPayloadOnly();
    }

    if (HasArg(args, "--uninstall"))
    {
        Uninstall();
        Console.WriteLine("Valley ERP Lojista removido.");
        return 0;
    }

    if (HasArg(args, "--startup-only"))
    {
        string installedExe = FindInstalledExecutable();
        bool startupOnlyRegistered = RegisterStartup(installedExe);
        Console.WriteLine("Inicializacao automatica: " + (startupOnlyRegistered ? "ativada" : "nao ativada"));
        return startupOnlyRegistered ? 0 : 1;
    }

    string appExe = InstallPayload();
    bool startupRegistered = HasArg(args, "--no-startup") ? false : RegisterStartup(appExe);
    WriteInstallState(appExe, startupRegistered);

    Console.WriteLine("Valley ERP Lojista instalado em: " + Path.GetDirectoryName(appExe));
    Console.WriteLine("Inicializacao automatica: " + (startupRegistered ? "ativada" : "nao ativada"));

    if (!HasArg(args, "--install-only"))
    {
        LaunchApp(appExe);
    }

    return 0;
}
catch (Exception ex)
{
    Console.Error.WriteLine("Falha ao instalar ou abrir Valley ERP: " + ex.Message);
    return 1;
}
