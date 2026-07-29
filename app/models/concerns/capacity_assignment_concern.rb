# Enforcement de capacidade (MIT), prepended em AutoAssignment::AssignmentService.
# Filtra da auto-atribuição os agentes que já atingiram o limite de conversas do
# inbox (via política de capacidade). Só age se houver política configurada.
module CapacityAssignmentConcern
  def find_available_agent(conversation = nil)
    agents = filter_agents_by_team(inbox.available_agents, conversation)
    return nil if agents.nil?

    agents = filter_agents_by_rate_limit(agents)
    agents = filter_agents_by_capacity(agents) if capacity_filtering_enabled?
    return nil if agents.empty?

    round_robin_selector.select_agent(agents)
  end

  private

  def filter_agents_by_capacity(agents)
    capacity_service = AutoAssignment::CapacityService.new
    agents.select { |agent_member| capacity_service.agent_has_capacity?(agent_member.user, inbox) }
  end

  def capacity_filtering_enabled?
    inbox.account.account_users.joins(:agent_capacity_policy).exists?
  end
end
