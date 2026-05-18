# Valley Admin Windows — Execução Master

Entrega implementada no diretório `apps/valley-admin-windows/` como aplicação desktop Windows baseada em Tauri + React.

## Escopo aplicado

- Contexto exclusivo: Valley Admin / Central Master / Modo Deus.
- UI de alta densidade para monitores widescreen.
- Splash bloqueante com `valley_desktop_opening_final_animated.mp4`.
- Branding principal com `VALLEY-ADMIN.png` e branding discreto por módulo com `VALLEY-BOTON.png`.
- Painéis de BI, tokenomics, APIs exclusivas, multi-tenant, flags globais, logs e console de auditoria.
- Atalhos: `F5` para atualizar, `Ctrl+P` para busca global.
- ACL conceitual `ROOT_ONLY` para conectores de estoque/importação.
- Auto-updater Tauri configurado para endpoint OTA silencioso.

## Arquivos de mídia exigidos

Adicionar estes assets reais em `apps/valley-admin-windows/public/assets/`:

- `valley_desktop_opening_final_animated.mp4`
- `VALLEY-ADMIN.png`
- `VALLEY-BOTON.png`

A aplicação possui fallback visual temporizado para ambiente de desenvolvimento, mas em produção a política é splash bloqueante até o fim do vídeo.

## Segredos e chaves

Não persistir chaves reais no cliente desktop. Usar cofre no backend e expor apenas endpoints assinados ao Admin.

## Build Windows

```bash
cd apps/valley-admin-windows
npm install
npm run build
npm run tauri:build:windows
```

## OTA

O endpoint configurado é placeholder:

`https://updates.valley.nexora.app/admin/windows/{{target}}/{{arch}}/{{current_version}}`

Antes de produção, substituir `REPLACE_WITH_TAURI_UPDATER_PUBLIC_KEY` pela chave pública real do updater.

## Observação de execução

Os arquivos de automação CI e script PowerShell foram preparados no pacote local de entrega, mas a gravação desses caminhos foi bloqueada por salvaguardas da ferramenta conectada. O app, runtime Tauri, UI, tipos, dados mock, busca, atalhos e configuração principal foram gravados no repositório.
