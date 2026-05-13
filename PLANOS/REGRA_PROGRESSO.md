# Regra de Progresso dos Planos

## Regra obrigatoria

- Todo plano persistido em `PLANOS/` deve ter checklist de etapas.
- Cada etapa deve usar `- [ ]` enquanto estiver pendente e `- [x]` quando estiver concluida.
- A cada nova acao concluida, o plano ativo e o `PLANOS/INDEX.md` devem ser atualizados.
- O progresso produzido e calculado por etapas concluidas sobre etapas totais.
- O percentual faltante e `100% - progresso produzido`.
- O acumulado do `INDEX.md` e calculado desde o primeiro plano listado no indice.

## Comando canonico

```powershell
python scripts\update_planos_progress.py
```

## Progresso acumulado atual

- Etapas concluidas: `216/217`.
- Produzido: `99.5%`.
- Falta produzir: `0.5%`.
