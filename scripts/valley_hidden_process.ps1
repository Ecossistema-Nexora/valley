# PROPOSITO: Iniciar processos longos do Valley no Windows sem abrir janelas de terminal.
# CONTEXTO: Cloudflare, Python, SSH, watchers e bridges podem gerar pop-ups quando iniciados por Start-Process.
# REGRAS: Usar CreateNoWindow=true, WindowStyle=Hidden, redirecionar logs para arquivo e nunca expor segredos em console.
# EXCECAO: browsers, janelas de teste visual e instrumentacao interativa podem abrir pop-up quando fazem parte da validacao.

Set-StrictMode -Version Latest

function ConvertTo-ValleyHiddenArgument {
    param([AllowNull()][object]$Value)

    $Text = [string]$Value
    if ($Text.Length -eq 0) {
        return '""'
    }

    $Escaped = $Text -replace '\\+$', '$0$0'
    $Escaped = $Escaped -replace '"', '\"'
    return '"' + $Escaped + '"'
}

function Join-ValleyHiddenArguments {
    param([string[]]$ArgumentList = @())

    if (-not $ArgumentList -or $ArgumentList.Count -eq 0) {
        return ''
    }

    return (@($ArgumentList) | ForEach-Object { ConvertTo-ValleyHiddenArgument $_ }) -join ' '
}

function Start-ValleyHiddenProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [string[]]$ArgumentList = @(),

        [string]$WorkingDirectory = (Get-Location).Path,

        [string]$StdoutLog = '',

        [string]$StderrLog = '',

        [switch]$Wait,

        [switch]$PassThru
    )

    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        $Command = Get-Command $FilePath -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($Command) {
            $FilePath = $Command.Source
        }
    }

    if ($StdoutLog) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $StdoutLog) -Force | Out-Null
    }
    if ($StderrLog) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $StderrLog) -Force | Out-Null
    }

    $Psi = [System.Diagnostics.ProcessStartInfo]::new()
    $Psi.WorkingDirectory = $WorkingDirectory
    $Psi.UseShellExecute = $false
    $Psi.CreateNoWindow = $true
    $Psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden

    $UsesFileRedirection = -not [string]::IsNullOrWhiteSpace($StdoutLog) -or -not [string]::IsNullOrWhiteSpace($StderrLog)
    if ($UsesFileRedirection) {
        $CommandLine = (ConvertTo-ValleyHiddenArgument $FilePath)
        $JoinedArguments = Join-ValleyHiddenArguments -ArgumentList $ArgumentList
        if ($JoinedArguments) {
            $CommandLine = "$CommandLine $JoinedArguments"
        }
        if ($StdoutLog) {
            $CommandLine = "$CommandLine 1>>$(ConvertTo-ValleyHiddenArgument $StdoutLog)"
        }
        if ($StderrLog) {
            $CommandLine = "$CommandLine 2>>$(ConvertTo-ValleyHiddenArgument $StderrLog)"
        }

        $Psi.FileName = $env:ComSpec
        $Psi.Arguments = '/d /s /c "' + $CommandLine + '"'
    } else {
        $Psi.FileName = $FilePath
        $Psi.Arguments = Join-ValleyHiddenArguments -ArgumentList $ArgumentList
    }

    $Process = [System.Diagnostics.Process]::Start($Psi)
    if ($Wait) {
        $Process.WaitForExit()
    }

    if ($PassThru -or $Wait) {
        return $Process
    }
}
