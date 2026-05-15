' PROPOSITO: Executar comandos de runtime Valley no Windows sem abrir janela de terminal.
' CONTEXTO: Usado por Scheduled Tasks e atalhos Startup para Cloudflare, bridges, watchdogs e rotinas longas.
' REGRAS: Janela sempre oculta; nao escrever segredos no console; browsers e testes visuais nao devem usar este runner.

Option Explicit

Dim shell
Dim workdir
Dim commandLine
Dim i

If WScript.Arguments.Count < 2 Then
    WScript.Quit 64
End If

workdir = WScript.Arguments.Item(0)
commandLine = WScript.Arguments.Item(1)

For i = 2 To WScript.Arguments.Count - 1
    commandLine = commandLine & " " & WScript.Arguments.Item(i)
Next

Set shell = CreateObject("WScript.Shell")
If Len(workdir) > 0 Then
    shell.CurrentDirectory = workdir
End If

shell.Run commandLine, 0, False
