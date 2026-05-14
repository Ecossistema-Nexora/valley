using System.Diagnostics;
using System.IO.Compression;
using System.Reflection;

const string ResourceName = "valley-erp-payload.zip";
const string AppFolderName = "ValleyERP-Lojista";
const string PackageFolderName = "ValleyERP-Lojista-Windows-x64";
const string AppExeRelativePath = "app/ValleyERP-Lojista.exe";

static string RequireWindowsLocalAppData()
{
    string? localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
    if (string.IsNullOrWhiteSpace(localAppData))
    {
        throw new InvalidOperationException("LOCALAPPDATA nao encontrado para instalar o Valley ERP.");
    }
    return localAppData;
}

static void CleanDirectory(string path)
{
    if (Directory.Exists(path))
    {
        Directory.Delete(path, recursive: true);
    }
    Directory.CreateDirectory(path);
}

static void ExtractPayload(string extractRoot)
{
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
    ZipFile.ExtractToDirectory(zipPath, extractRoot, overwriteFiles: true);
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

try
{
    if (!OperatingSystem.IsWindows())
    {
        Console.Error.WriteLine("Este arquivo e o executavel Windows. Use Valley-ERP-Linux.run no Linux.");
        return 2;
    }

    string localAppData = RequireWindowsLocalAppData();
    string installRoot = Path.Combine(localAppData, "Programs", AppFolderName, "single-v050");
    CleanDirectory(installRoot);
    ExtractPayload(installRoot);

    string appExe = FindExecutable(installRoot);
    ProcessStartInfo startInfo = new()
    {
        FileName = appExe,
        WorkingDirectory = Path.GetDirectoryName(appExe) ?? installRoot,
        UseShellExecute = true,
    };
    startInfo.Environment["VALLEY_PRODUCT_API_BASE_URL"] = "https://admin.brasildesconto.com.br";
    Process.Start(startInfo);
    return 0;
}
catch (Exception ex)
{
    Console.Error.WriteLine("Falha ao abrir Valley ERP: " + ex.Message);
    return 1;
}
