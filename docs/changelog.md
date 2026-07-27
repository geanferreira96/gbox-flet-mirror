# Changelog — Gbox

Notas de versão do Gbox. O bloco da versão atual também é usado como comentário
da release no mirror (`scripts/release_mirror.ps1`).

## Versão 2.6.8

### Correções

- Corrigida a **tela preta** ao abrir o Visualizador de Mapa (ou outras ferramentas) a partir do menu inferior com a home vazia no APK/EXE: o app agora espera o BottomSheet terminar o dismiss antes de montar a aba.
- Diálogos padronizados e banner de “em desenvolvimento” passam a usar `show_dialog` / `pop_dialog` (API Flet 0.86), evitando barreira modal presa.

### Melhorias

- Stack atualizado para **Flet 0.86** (Python do bundle Android **3.14**), com `flet-mcp` para agilizar desenvolvimento no Cursor.
- Nova compilação **APK v2 (single-pass)** e **Fast push** para iterar só no código Python sem rebuild Flutter/Gradle.
- Tasks do VS Code unificadas com seletor de arquitetura: **Compilar v2**, **Enviar** e **Fast push** (v7/v8).
- Versão do app sincronizada automaticamente do `pyproject.toml` para `src/__version__.py` em toda compilação (`VERSION_GBOX` lê desse arquivo).

## Versão 2.6.6

### Correções

- Ajustes de build Android (estado compartilhado entre ABI v7/v8) e publicação no mirror.
