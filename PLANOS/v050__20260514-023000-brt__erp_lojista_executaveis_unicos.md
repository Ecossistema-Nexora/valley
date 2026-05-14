PROPOSITO: Entregar o ERP Lojista como um unico arquivo executavel por plataforma.
CONTEXTO: O usuario exigiu que Windows e Linux nao dependam de ZIP/TAR como entrega principal; o Windows deve ter um arquivo como Valley-ERP.exe.
REGRAS: Manter a UI release blueprint funcional, usar o runtime publico validado e preservar os pacotes duraveis anteriores como suporte secundario.

# v050 - ERP Lojista em Executaveis Unicos

## Checklist

- [ ] Criar empacotador Windows de arquivo unico `Valley-ERP.exe`.
- [ ] Criar empacotador Linux de arquivo unico executavel.
- [ ] Rebuildar o ERP Lojista com base publica `https://admin.brasildesconto.com.br`.
- [ ] Gerar artefatos v050 e manifest com hashes.
- [ ] Validar links publicos dos executaveis.
- [ ] Acionar Valley Module Automation Engine.

## Criterios De Aceite

- Windows possui um unico arquivo `Valley-ERP.exe` como entrega principal.
- Linux possui um unico arquivo executavel como entrega principal.
- Os artefatos apontam para o runtime publico fixo validado.
- Links publicos dos artefatos respondem antes de qualquer envio externo.
