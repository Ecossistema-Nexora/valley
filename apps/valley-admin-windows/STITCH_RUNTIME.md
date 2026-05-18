# Stitch Runtime Local

Use `opencode.stitch.example.toml` como base e copie para um arquivo local não versionado antes de iniciar o runtime OpenCode.

O valor sensível deve ser aplicado somente no ambiente local de execução, nunca em commit público.

Arquivo recomendado para execução local:

```toml
[mcp_servers.stitch]
url = "https://stitch.googleapis.com/mcp"

[mcp_servers.stitch.http_headers]
"X-Goog-Api-Key" = "${STITCH_API_KEY}"
```

O operador pode exportar `STITCH_API_KEY` no shell antes de iniciar o OpenCode.
