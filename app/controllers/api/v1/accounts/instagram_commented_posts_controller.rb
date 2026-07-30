# Tela post-centrica de Comentarios do Instagram: agrupa os comentarios por POST
# (instagram_media_id), com contagem e horario do ultimo, e enriquece cada post com
# imagem/permalink/legenda via a Graph (Instagram::MediaLookupService).
#
# O agrupamento e feito em RUBY (nao em SQL) de proposito: content_attributes da mensagem
# e uma coluna `json` com o hash serializado como STRING (double-encoded), entao
# `content_attributes ->> 'x'` nao funciona; e o CommentBuilder reusa 1 conversa por
# contato entre posts diferentes, entao agrupar por conversa tambem erraria a contagem.
#
# GET /api/v1/accounts/:account_id/instagram_commented_posts        -> galeria de posts
# GET /api/v1/accounts/:account_id/instagram_commented_posts/:id    -> detalhe (id = media_id)
class Api::V1::Accounts::InstagramCommentedPostsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  # Cap de posts enriquecidos por request: cada media_id sem cache = 1 chamada Graph.
  MAX_POSTS = 24

  def index
    grouped = comment_messages.group_by { |message| media_id_of(message) }
    grouped.delete(nil)

    ordered = grouped.keys
                     .sort_by { |mid| -grouped[mid].map(&:created_at).max.to_i }
                     .first(MAX_POSTS)

    posts = ordered.map do |mid|
      messages = grouped[mid]
      {
        media_id: mid,
        comment_count: messages.size,
        last_comment_at: messages.map(&:created_at).max.to_i
      }.merge(lookup_post(messages.first, mid).symbolize_keys)
    end

    render json: { payload: posts }
  end

  def show
    messages = comment_messages
               .select { |message| media_id_of(message).to_s == params[:id].to_s }
               .sort_by(&:created_at)

    details = messages.any? ? lookup_post(messages.first, params[:id]) : {}

    render json: {
      post: details.merge('media_id' => params[:id]),
      comments: messages.map { |message| serialize_comment(message) }
    }
  end

  private

  # Nao existe model InstagramCommentedPost pra auto-constantizar; a leitura segue a
  # permissao de conversa (ConversationPolicy#index?/show? => true).
  def check_authorization
    authorize(Conversation)
  end

  # Mensagens de comentario das conversas de comentario da conta. O filtro is_instagram_comment
  # roda em Ruby (o model desserializa content_attributes); a lista ja e limitada ao volume
  # de comentarios (conversas type=instagram_comment), fora as atividades de resposta.
  def comment_messages
    @comment_messages ||= Message
                          .where(conversation_id: comment_conversation_ids)
                          .where(deleted: false)
                          .includes(:sender, conversation: { inbox: :channel })
                          .to_a
                          .select { |message| message.content_attributes['is_instagram_comment'] }
  end

  def comment_conversation_ids
    Current.account.conversations
           .where("additional_attributes ->> 'type' = ?", 'instagram_comment')
           .select(:id)
  end

  def media_id_of(message)
    message.content_attributes['instagram_media_id']
  end

  def lookup_post(message, media_id)
    channel = message&.conversation&.inbox&.channel
    return {} unless channel

    Instagram::MediaLookupService.new(channel: channel, media_id: media_id).perform
  end

  def serialize_comment(message)
    attrs = message.content_attributes || {}
    {
      comment_id: attrs['instagram_comment_id'],
      parent_id: attrs['instagram_parent_comment_id'],
      text: message.content,
      created_at: message.created_at.to_i,
      conversation_id: message.conversation.display_id,
      author: {
        name: message.sender&.name,
        thumbnail: message.sender.try(:avatar_url).presence
      }
    }
  end
end
