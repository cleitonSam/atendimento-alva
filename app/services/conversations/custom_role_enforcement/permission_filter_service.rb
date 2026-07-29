# Enforcement de cargos personalizados (MIT) — prepended em
# Conversations::PermissionFilterService. Restringe QUAIS conversas o agente
# enxerga nas listagens/contadores/ações em massa conforme o custom_role.
# Sem isto, as policies gateiam só o acesso por-registro (show?), mas a
# LISTA continuaria expondo todas as conversas do inbox.
# Hierarquia: conversation_manage > conversation_unassigned_manage >
# conversation_participating_manage.
module Conversations
  module CustomRoleEnforcement
    module PermissionFilterService
      def perform
        return filter_by_permissions(permissions) if user_has_custom_role?

        super
      end

      private

      def user_has_custom_role?
        user_role == 'agent' && account_user&.custom_role_id.present?
      end

      def permissions
        account_user&.permissions || []
      end

      def filter_by_permissions(permissions)
        if permissions.include?('conversation_manage')
          accessible_conversations
        elsif permissions.include?('conversation_unassigned_manage')
          filter_unassigned_and_mine
        elsif permissions.include?('conversation_participating_manage')
          filter_participating_and_mine
        else
          Conversation.none
        end
      end

      def filter_participating_and_mine
        conversations = accessible_conversations
        participant_conversation_ids = ConversationParticipant.where(account_id: account.id, user_id: user.id).select(:conversation_id)

        conversations
          .where(assignee_id: user.id)
          .or(conversations.where(id: participant_conversation_ids))
      end

      def filter_unassigned_and_mine
        accessible_conversations.where(assignee_id: [nil, user.id])
      end
    end
  end
end
