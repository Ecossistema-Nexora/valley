PROPOSITO: Documentar os executaveis unicos do Valley ERP Lojista V050.
CONTEXTO: Esta release troca a entrega principal ZIP/TAR por um arquivo executavel por plataforma.
REGRAS: Usar os links publicos abaixo apenas depois de health HTTP 200 no dominio fixo Cloudflare.

# Valley ERP Lojista - Executaveis Unicos V050

## Links

- Windows: https://admin.brasildesconto.com.br/downloads/v050/Valley-ERP.exe
- Linux: https://admin.brasildesconto.com.br/downloads/v050/Valley-ERP-Linux.run
- Manifesto: https://admin.brasildesconto.com.br/downloads/v050/VALLEY_ERP_SINGLE_EXECUTABLES_V050.json

## Observacoes

- O Windows Valley-ERP.exe embute o pacote desktop e abre ValleyERP-Lojista.exe.
- O Linux Valley-ERP-Linux.run embute o pacote Linux e tenta instalar/executar o app; quando o host Linux nao tem bundle nativo compilado, cria launcher unico para o runtime publico validado.
- API base: https://admin.brasildesconto.com.br