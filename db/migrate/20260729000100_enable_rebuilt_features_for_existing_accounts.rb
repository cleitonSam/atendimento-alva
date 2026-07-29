# Liga, nas contas JÁ existentes, os features que reconstruímos/destravamos em MIT.
# O config/features.yml (enabled:true) só vale para contas NOVAS (enable_default_features
# roda na criação); contas antigas ficaram sem os bits, então numa instância white-label
# o usePolicy.shouldShow escondia os menus (Audit Logs, SLA, Custom Roles, Companies,
# Security/SAML). Idempotente — reabilitar um feature já ligado é no-op.
class EnableRebuiltFeaturesForExistingAccounts < ActiveRecord::Migration[7.1]
  FEATURES = %w[audit_logs sla custom_roles companies disable_branding saml].freeze

  def up
    Account.find_each do |account|
      account.enable_features(*FEATURES)
      account.save!
    end
  end

  def down
    # no-op: não desligamos features no rollback
  end
end
