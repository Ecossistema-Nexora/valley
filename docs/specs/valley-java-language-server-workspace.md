# Valley Java Language Server Workspace Policy

## Contexto

O workspace Valley e um app Flutter com projeto Android interno. A extensao Red Hat Java pode tentar importar o Gradle Android como projeto Java raiz e detectar automaticamente JDKs instalados no Windows.

Em 2026-04-22, o Java Language Server travou ao tentar detectar bibliotecas do OpenJDK 8 da Red Hat em:

```text
C:\Program Files\RedHat\java-1.8.0-openjdk-1.8.0.482-1
```

## Decisao persistente

- O workspace fixa o Java Language Server no Microsoft JDK 21.
- A deteccao automatica de JDKs fica desligada.
- Import Maven/Gradle e autobuild Java ficam desligados para este workspace.
- Builds Android/Flutter continuam sendo executados por `flutter`/Gradle, nao pelo Java Language Server.

## Configuracao

Arquivo: `.vscode/settings.json`

```json
"java.jdt.ls.java.home": "C:\\Program Files\\Microsoft\\jdk-21.0.10.7-hotspot",
"java.configuration.runtimes": [
  {
    "name": "JavaSE-21",
    "path": "C:\\Program Files\\Microsoft\\jdk-21.0.10.7-hotspot",
    "default": true
  }
],
"java.configuration.detectJdksAtStart": false,
"java.configuration.updateBuildConfiguration": "disabled",
"java.import.gradle.enabled": false,
"java.import.maven.enabled": false,
"java.autobuild.enabled": false
```

## Recuperacao se o erro continuar aberto no IDE

1. Execute `Java: Clean Java Language Server Workspace`.
2. Recarregue a janela do editor.
3. Se ainda houver lock Equinox antigo, feche o editor e abra novamente.
