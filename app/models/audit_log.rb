# Modelo de auditoria próprio (MIT) — subclasse do Audited::Audit (gem OSS).
# Substitui o Enterprise::AuditLog. Configurado em config/initializers/audited.rb.
# É o audit_class usado por `has_associated_audits` (Account) e pelo viewer.
class AuditLog < Audited::Audit
end
