PROPOSITO: Documentar os executaveis unicos do Valley ERP Lojista V055.
CONTEXTO: Esta release troca a entrega principal ZIP/TAR por um arquivo executavel por plataforma.
REGRAS: Usar os links publicos abaixo apenas depois de health HTTP 200 no dominio fixo Cloudflare.

# Valley ERP Lojista - Executaveis Unicos V055

## Links

- Windows: https://admin.brasildesconto.com.br/downloads/v055/Valley-ERP.exe
- Linux: https://admin.brasildesconto.com.br/downloads/v055/Valley-ERP-Linux.run
- Manifesto: https://admin.brasildesconto.com.br/downloads/v055/VALLEY_ERP_SINGLE_EXECUTABLES_V055.json

## Observacoes

- O Windows Valley-ERP.exe e o instalador nativo principal: embute o pacote desktop, valida o payload com --check, instala em %LOCALAPPDATA%\Programs\ValleyERP-Lojista e registra inicializacao automatica do ERP no Windows via HKCU\Software\Microsoft\Windows\CurrentVersion\Run.
- Comandos nativos do Windows: Valley-ERP.exe --check, Valley-ERP.exe --install-only, Valley-ERP.exe --startup-only, Valley-ERP.exe --no-startup e Valley-ERP.exe --uninstall.
- O Linux Valley-ERP-Linux.run embute o pacote Linux e tenta instalar/executar o app; quando o host Linux nao tem bundle nativo compilado, cria launcher unico para o runtime publico validado.
- API base: https://admin.brasildesconto.com.br