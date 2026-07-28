# template-base

Repositório template com o padrão de engenharia, segurança e automação usado em todos os projetos de **@cleitonSam**.
Use o botão **Use this template** para começar qualquer projeto novo já dentro do padrão.

![License](https://img.shields.io/github/license/cleitonSam/template-base)

## O que vem pronto

| Item | Arquivo | Função |
| ---- | ------- | ------ |
| Pipeline de qualidade | `.github/workflows/ci.yml` | Lint, tipagem, testes, cobertura e build |
| Análise estática de segurança | `.github/workflows/codeql.yml` | CodeQL semanal e em pull request |
| Revisão de dependências | `.github/workflows/dependency-review.yml` | Bloqueia dependência vulnerável no PR |
| Varredura de segredos | `.github/workflows/secret-scan.yml` | Impede vazamento de credencial |
| Release automatizada | `.github/workflows/release.yml` | Tag, CHANGELOG e notas por SemVer |
| Atualização de dependências | `.github/dependabot.yml` | PRs agrupados semanais |
| Revisor obrigatório | `.github/CODEOWNERS` | Define quem aprova cada área |
| Padrão de commit | `commitlint.config.cjs` | Conventional Commits validado no CI |
| Estilo de arquivo | `.editorconfig`, `.prettierrc.json` | Formatação idêntica em qualquer editor |
| Documentação mínima | `docs/` | Arquitetura, ADR e runbook |

Políticas de contribuição, segurança, conduta e templates de issue e PR são herdados de [cleitonSam/.github](https://github.com/cleitonSam/.github).

## Como usar

1. Clique em **Use this template > Create a new repository**.
2. Defina nome no padrão (`api-`, `web-`, `dash-`, `lp-`, `app-`, `lib-`, `infra-`), descrição e topics.
3. Substitua este README pelo [modelo oficial](https://github.com/cleitonSam/.github/blob/main/docs/MODELO-README.md).
4. Ajuste `.env.example`, `CODEOWNERS` e o `dependabot.yml` para a stack do projeto.
5. Aplique as configurações de segurança descritas em `docs/SETUP-SEGURANCA.md`.
6. Percorra o [checklist de novo projeto](https://github.com/cleitonSam/.github/blob/main/docs/CHECKLIST-NOVO-PROJETO.md).

## Estrutura

```
.github/
  workflows/    ci, codeql, dependency-review, secret-scan, release
  CODEOWNERS
  dependabot.yml
docs/
  ARCHITECTURE.md
  RUNBOOK.md
  SETUP-SEGURANCA.md
  adr/
src/
tests/
```

## Comandos esperados em qualquer projeto

| Comando | Função |
| ------- | ------ |
| `npm run dev` | Ambiente de desenvolvimento |
| `npm run build` | Build de produção |
| `npm test` | Testes |
| `npm run lint` | Análise estática |
| `npm run format` | Formatação |

Projetos em outra stack devem expor comandos equivalentes com os mesmos nomes de intenção.

## Licença

MIT. Veja [LICENSE](LICENSE).
