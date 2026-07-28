# Setup de Segurança do Repositório

> Arquivos versionados resolvem metade do problema. A outra metade está nas configurações do repositório e da conta, que precisam ser aplicadas manualmente pelo dono.

## 1. Conta (faça uma vez)

| Onde | O que ativar |
| ---- | ------------ |
| Settings > Password and authentication | Autenticação em dois fatores com app autenticador e códigos de recuperação guardados fora do computador |
| Settings > SSH and GPG keys | Chave de assinatura GPG ou SSH cadastrada |
| Settings > SSH and GPG keys | Opção Flag unsigned commits as unverified ativada |
| Settings > Code security | Alertas do Dependabot, atualizações de segurança e secret scanning ativados por padrão para novos repositórios |
| Settings > Developer settings > Tokens | Usar apenas fine-grained tokens, com escopo mínimo e validade curta |

Assinatura local de commits:

```bash
git config --global user.signingkey <ID_DA_CHAVE>
git config --global commit.gpgsign true
git config --global tag.gpgsign true
git config --global pull.rebase true
git config --global init.defaultBranch main
```

## 2. Repositório: Settings > General

- Default branch: `main`.
- Allow merge commits: desativado.
- Allow squash merging: ativado, com título do PR como mensagem padrão.
- Allow rebase merging: opcional.
- Automatically delete head branches: ativado.
- Template repository: ativado apenas no `template-base`.

## 3. Repositório: Settings > Rules > Rulesets (ou Branch protection)

Regra aplicada a `main`:

- Require a pull request before merging, com 1 aprovação.
- Dismiss stale approvals quando houver novo push.
- Require review from Code Owners.
- Require conversation resolution before merging.
- Require status checks to pass: `Lint, testes e build`, `Conventional Commits`, `Procurar credenciais expostas`, `Revisar dependencias do pull request` e `Analisar javascript-typescript`.
- Require branches to be up to date before merging.
- Require signed commits.
- Require linear history.
- Block force pushes.
- Restrict deletions.
- **Não** marcar exceção para administradores.

## 4. Repositório: Settings > Code security and analysis

- Private vulnerability reporting: ativado.
- Dependency graph: ativado.
- Dependabot alerts: ativado.
- Dependabot security updates: ativado.
- Secret scanning: ativado.
- Push protection: ativado (impede o push que contém segredo).
- Code scanning: default setup ou o workflow `codeql.yml` deste template.

## 5. Repositório: Settings > Actions

- Actions permissions: permitir apenas actions do GitHub e actions verificadas ou explicitamente listadas.
- Workflow permissions: **Read repository contents**. Elevar apenas dentro do workflow que precisa.
- Allow GitHub Actions to create and approve pull requests: ativado somente se usar release automatizada.
- Fork pull request workflows: exigir aprovação para todos os colaboradores externos.

## 6. Repositório: Settings > Environments

- Criar `production` com required reviewers e branch protegida.
- Segredos de produção vivem no environment, nunca no nível do repositório.

## 7. Se um segredo vazou

1. Revogue a credencial imediatamente na origem. Remover do Git não basta: o segredo já está comprometido.
2. Gere uma nova credencial e atualize os ambientes.
3. Verifique logs de acesso em busca de uso indevido.
4. Limpe o histórico com `git filter-repo` apenas depois de revogar.
5. Registre o incidente no `RUNBOOK.md` com causa raiz e ação preventiva.

## 8. Revisão trimestral

- Revogar tokens e chaves não utilizados.
- Revisar colaboradores e permissões.
- Fechar alertas de segurança pendentes.
- Conferir se todo repositório ativo ainda cumpre o padrão.
