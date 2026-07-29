# Diz se um agente ainda tem capacidade para receber conversa num inbox, com base
# na política de capacidade do agente e no limite daquele inbox. Reconstruído em MIT.
class AutoAssignment::CapacityService
  def agent_has_capacity?(user, inbox)
    account_user = user.account_users.find_by(account: inbox.account)

    # Sem account_user ou sem política de capacidade => capacidade ilimitada
    return true unless account_user&.agent_capacity_policy

    policy = account_user.agent_capacity_policy
    inbox_limit = policy.inbox_capacity_limits.find_by(inbox: inbox)

    # Sem limite específico para este inbox => ilimitado neste inbox
    return true unless inbox_limit

    current_count = user.assigned_conversations
                        .where(inbox: inbox, status: :open)
                        .count

    current_count < inbox_limit.conversation_limit
  end
end
