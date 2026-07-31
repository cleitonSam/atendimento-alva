# Conjuntos de hashtags sao recurso compartilhado da conta (sem dono). Como Labels,
# qualquer membro le, mas so admin altera/apaga (evita um agente sobrescrever o do outro).
class InstagramHashtagSetPolicy < ApplicationPolicy
  def index?
    @account_user.administrator? || @account_user.agent?
  end

  def create?
    @account_user.administrator?
  end

  def update?
    create?
  end

  def destroy?
    create?
  end
end
