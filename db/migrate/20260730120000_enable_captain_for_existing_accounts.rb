# Liga o Captain (FAQ Suggestions review) nas contas JÁ existentes. O features.yml
# (enabled:true) só vale para contas novas; contas antigas ficam sem o bit e o menu
# não aparece. Idempotente — reabilitar um feature já ligado é no-op.
class EnableCaptainForExistingAccounts < ActiveRecord::Migration[7.1]
  def up
    Account.find_each do |account|
      account.enable_features('captain_integration')
      account.save!
    end
  end

  def down
    # no-op: não desligamos features no rollback
  end
end
