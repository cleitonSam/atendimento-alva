# Runbook de Operação

> Documento de plantão. Deve permitir que qualquer pessoa diagnostique e reverta um problema sem depender de memória.

## Identificação

| Item | Valor |
| ---- | ----- |
| Serviço | {} |
| Responsável | @cleitonSam |
| Criticidade | {alta / média / baixa} |
| Horário crítico | {} |

## Ambientes

| Ambiente | URL | Branch | Deploy |
| -------- | --- | ------ | ------ |
| Produção | {} | `main` | {} |
| Homologação | {} | `develop` | {} |
| Local | http://localhost:3000 | qualquer | `npm run dev` |

## Verificação rápida de saúde

```bash
curl -fsS https://{dominio}/health
```

Checar também: status do banco, fila de jobs, uso de memória e taxa de erro dos últimos 15 minutos.

## Sintomas e primeira ação

| Sintoma | Causa provável | Primeira ação |
| ------- | -------------- | ------------- |
| Erro 500 generalizado | Deploy recente quebrado | Reverter para a release anterior |
| Lentidão alta | Consulta sem índice ou pico de tráfego | Identificar query lenta e aplicar cache ou índice |
| Falha de autenticação em massa | Segredo expirado ou rotacionado | Conferir variáveis do ambiente |
| Fila acumulando | Worker parado | Reiniciar worker e investigar erro |
| Banco indisponível | Limite de conexões ou incidente do provedor | Verificar pool e status do provedor |

## Deploy

1. Confirmar pipeline verde em `main`.
2. {Comando ou gatilho de deploy}
3. Validar health check e principais fluxos.
4. Observar taxa de erro por 15 minutos.

## Rollback

1. Identificar a última release estável.
2. {Comando de rollback}
3. Reverter migração de banco somente se for reversível e necessário.
4. Validar health check.
5. Abrir issue com rótulo de incidente registrando causa e ação.

## Backup e restauração

- Frequência do backup: {}
- Local e retenção: {}
- Último teste de restauração: {data}
- Backup sem teste de restauração não é backup.

## Comunicação de incidente

1. Registrar início, impacto e usuários afetados.
2. Informar as partes interessadas com estimativa realista.
3. Atualizar a cada 30 minutos enquanto durar.
4. Após resolver, escrever post-mortem sem culpados, com causa raiz e ação preventiva.

## Histórico de incidentes

| Data | Duração | Impacto | Causa raiz | Ação preventiva |
| ---- | ------- | ------- | ---------- | --------------- |
| | | | | |
