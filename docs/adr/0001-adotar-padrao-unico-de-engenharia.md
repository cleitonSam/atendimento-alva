# ADR 0001 - Adotar um padrão único de engenharia para todos os repositórios

- **Status:** aceito
- **Data:** 2026-07-28
- **Decisores:** @cleitonSam

## Contexto

Os repositórios cresceram sem padrão comum: nomes inconsistentes, ausência de README e licença em parte deles, nenhuma automação de qualidade, nenhuma varredura de segurança e commits sem convenção. Isso aumenta o tempo para retomar um projeto antigo, esconde risco de vazamento de credencial e prejudica a percepção técnica de quem avalia o trabalho.

## Decisão

1. Criar o repositório `cleitonSam/.github` como fonte única das políticas de contribuição, segurança, conduta, suporte e templates de issue e pull request.
2. Criar o repositório template `cleitonSam/template-base` com CI, CodeQL, dependency review, varredura de segredos, Dependabot, CODEOWNERS, Conventional Commits e documentação mínima.
3. Todo projeto novo nasce do template. Todo projeto existente e ativo é migrado para o padrão.
4. `main` protegida, merge apenas por pull request revisado com pipeline verde.
5. Commits assinados e no padrão Conventional Commits.
6. Versão e CHANGELOG derivados dos commits, sem edição manual.

## Alternativas consideradas

| Alternativa | Por que foi descartada |
| ----------- | ---------------------- |
| Manter cada projeto com o próprio padrão | Custo de contexto alto e risco de segurança desigual entre projetos |
| Documentar o padrão apenas em texto, sem automação | Regra que não é verificada por CI não é cumprida de forma consistente |
| Usar organização do GitHub com regras globais | Recursos relevantes de ruleset global exigem plano pago e a conta é pessoal |

## Consequências

**Positivas**

- Um repositório novo já nasce com qualidade e segurança automatizadas.
- Menor tempo para retomar um projeto antigo.
- Rastreabilidade real do histórico e das decisões.
- Portfólio público coerente e verificável.

**Negativas ou custos**

- Esforço inicial para migrar repositórios antigos.
- Fluxo mais rígido: sem commit direto em `main`, mesmo para o dono.
- Manutenção dos workflows e das versões de actions ao longo do tempo.

## Revisão

Reavaliar em 12 meses ou quando a conta migrar para uma organização.
