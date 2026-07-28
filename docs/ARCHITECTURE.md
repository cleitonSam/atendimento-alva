# Arquitetura

> Preencha este documento no início do projeto e atualize sempre que uma decisão estrutural mudar.

## Visão geral

{O que o sistema faz, quem usa e qual problema de negócio resolve.}

## Diagrama de contexto

```
[Usuario] --> [Frontend] --> [API] --> [Banco de dados]
                              |
                              +--> [Servico externo]
```

## Componentes

| Componente | Responsabilidade | Tecnologia | Observação |
| ---------- | ---------------- | ---------- | ---------- |
| Frontend | Interface e experiência | {} | |
| API | Regras de negócio | {} | |
| Banco | Persistência | {} | |
| Fila / Jobs | Processamento assíncrono | {} | |

## Fluxo principal

1. {Entrada}
2. {Validação e autorização}
3. {Processamento}
4. {Persistência}
5. {Resposta e efeitos colaterais}

## Modelo de dados

{Entidades principais e relacionamentos. Aponte para as migrações como fonte de verdade.}

## Autenticação e autorização

- Mecanismo: {}
- Papéis e permissões: {}
- Onde a autorização é verificada: {}

## Dados sensíveis

| Dado | Onde fica | Proteção | Retenção |
| ---- | --------- | -------- | -------- |
| {} | {} | {criptografia em repouso e em trânsito} | {} |

## Integrações externas

| Serviço | Uso | Falha tolerada | Plano de contingência |
| ------- | --- | -------------- | --------------------- |
| {} | {} | {} | {} |

## Decisões e limites conhecidos

- {Escolha relevante e o motivo.}
- {Limitação aceita consciente e quando revisitar.}

Decisões formais ficam em [adr/](adr/).

## Escalabilidade e desempenho

- Gargalo esperado: {}
- Estratégia de cache: {}
- Meta de tempo de resposta: {}
