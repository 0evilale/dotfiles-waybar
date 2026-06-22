# AGENTS.md

## Git Push

Para subir cambios a GitHub, usar el CLI `gh` (autenticado en el keyring). El remote HTTPS no tiene credenciales propias y no hay llave SSH configurada, por lo que `git push` directo falla.

Antes de pushear, configurar el credential helper de gh:

```bash
gh auth setup-git -h github.com
```

Luego `git push` usará el token de `gh` automáticamente.
