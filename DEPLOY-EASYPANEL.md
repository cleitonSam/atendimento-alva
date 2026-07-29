# Deploy — ALVA IA TECH (EasyPanel)

> Molde de configuração. **Sem segredos aqui** — os valores reais (senhas, chaves)
> você cola direto no painel do EasyPanel (Serviço → Environment). O `.env` nunca
> vai pro git.

## Variáveis de ambiente

Cole o mesmo conjunto nos **DOIS serviços**: `web` (Rails) e `worker` (Sidekiq).
Troque tudo que está entre `< >`.

```bash
# ---- CORE / SEGURANÇA ----
RAILS_ENV=production
NODE_ENV=production
INSTALLATION_ENV=docker
RAILS_LOG_TO_STDOUT=true
# Gere: docker compose run --rm rails bundle exec rails secret
SECRET_KEY_BASE=<gere-uma-chave-longa>
# Comece false; troque para true depois de validar o domínio (ver passo 7)
FORCE_SSL=false

# 2FA/MFA é obrigatório neste fork. Gere as 3 com: rails db:encryption:init
# (iguais em web e worker; nunca troque depois, senão perde os segredos de 2FA)
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=<primary-key>
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=<deterministic-key>
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=<salt>

# ---- URL / DOMÍNIO ----  (origem https EXATA, sem barra final)
FRONTEND_URL=https://<seu-dominio>
DEFAULT_LOCALE=pt_BR

# ---- POSTGRES (a imagem PRECISA ter pgvector) ----
POSTGRES_HOST=<host-do-postgres>
POSTGRES_PORT=5432
POSTGRES_USERNAME=<usuario>
POSTGRES_PASSWORD=<senha>
POSTGRES_DATABASE=<banco>
PGSSLMODE=disable            # a gem pg lê PGSSLMODE (não "sslmode" na URL)

# ---- REDIS (senha em UMA fonte só; não embutir na URL) ----
REDIS_URL=redis://<host-do-redis>:6379
REDIS_PASSWORD=<senha-do-redis>

# ---- STORAGE: MinIO / S3-compatível (usa o bloco s3_compatible do repo) ----
ACTIVE_STORAGE_SERVICE=s3_compatible
STORAGE_ACCESS_KEY_ID=<access-key>
STORAGE_SECRET_ACCESS_KEY=<secret-key>
STORAGE_REGION=us-east-1
STORAGE_BUCKET_NAME=<bucket>          # crie o bucket antes do 1º upload
STORAGE_ENDPOINT=https://<endpoint-API-S3>   # porta 9000 (API), NÃO o console (9001)
STORAGE_FORCE_PATH_STYLE=true

# ---- PRODUÇÃO ----
WEB_CONCURRENCY=2
RAILS_MAX_THREADS=5
ENABLE_RACK_ATTACK=true

# ---- SMTP (opcional — reset de senha / convites) ----
# MAILER_SENDER_EMAIL=ALVA IA TECH <no-reply@seu-dominio>
# SMTP_ADDRESS=smtp.seuprovedor.com
# SMTP_PORT=587
# SMTP_USERNAME=
# SMTP_PASSWORD=
# SMTP_AUTHENTICATION=login
# SMTP_ENABLE_STARTTLS_AUTO=true
```

## Passos

**0. Pré-requisitos (senão nem sobe):**
- **Postgres com pgvector** — o schema faz `enable_extension "vector"` e dá *raise* se faltar. Use imagem `pgvector/pgvector:pg16` (ou similar).
- **Redis** com `requirepass` = `REDIS_PASSWORD`. Se o Redis não tem senha, **remova** `REDIS_PASSWORD`.
- **Bucket** criado no MinIO (mesmo nome de `STORAGE_BUCKET_NAME`).
- **Endpoint S3 do MinIO** = porta **9000** (API), não o console (9001).

**1. Build:** aponte o serviço pro repo e use o **`docker/Dockerfile`**. `SECRET_KEY_BASE` não é preciso no build (só em runtime).

**2. Dois serviços, o MESMO env:**
- **web** → `bundle exec rails s -p 3000 -b 0.0.0.0` (porta 3000 + domínio)
- **worker** → `bundle exec sidekiq -C config/sidekiq.yml`
- A imagem final não tem CMD — você DEFINE o start command nos dois.

**3. Migração (one-off, no console do web):**
```bash
POSTGRES_STATEMENT_TIMEOUT=600s bundle exec rails db:chatwoot_prepare
```

**4. 2FA:** as 3 `ACTIVE_RECORD_ENCRYPTION_*` precisam ser idênticas em web e worker.

**5. Storage:** nada a editar no código — o `config/storage.yml` já tem o bloco `s3_compatible` que lê `STORAGE_ENDPOINT` + `STORAGE_FORCE_PATH_STYLE`.

**6. SDK / widget:** o `assets:precompile` (no build do Docker) já gera `public/packs/js/sdk.js` com os globais `alva*`. O script de instalação de cada inbox aponta sozinho pro `FRONTEND_URL`.

**7. Go-live:** valide (login, upload, Sidekiq processando) com `FORCE_SSL=false`; depois troque para `true` e faça redeploy.

## Branding
A marca (ALVA IA TECH, cores, fontes, logos) vem do código e do `config/installation_config.yml` — **não há variável de env de marca**. O Super Admin pode trocar nome/logo/URLs pela UI (configs destravadas com `locked: false`).
