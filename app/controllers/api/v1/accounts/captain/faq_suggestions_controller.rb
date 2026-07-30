# Captain FAQ Suggestions — reconstrução MIT do backend (o front já existe no core).
# Serve o contrato exato de app/javascript/dashboard/api/captain/faqSuggestions.js:
#   index  -> { payload: [...], meta: { total_count, page } }   (filtra assistant_id/status/search)
#   show   -> objeto + observations (SEM envelope)
#   update -> objeto COMPLETO com id (a mutation EDIT do front casa por id)
#   approve-> cria Captain::AssistantResponse e marca approved (corpo ignorado pelo front)
#   dismiss-> marca dismissed
class Api::V1::Accounts::Captain::FaqSuggestionsController < Api::V1::Accounts::BaseController
  RESULTS_PER_PAGE = 25

  before_action :check_authorization
  before_action :set_faq_suggestion, only: [:show, :update, :approve, :dismiss]

  def index
    suggestions = scope
    suggestions = suggestions.where(assistant_id: params[:assistant_id]) if params[:assistant_id].present?
    suggestions = suggestions.where(status: params[:status]) if valid_status?
    suggestions = suggestions.where('captain_faq_suggestions.question ILIKE :q OR captain_faq_suggestions.answer ILIKE :q',
                                    q: "%#{params[:search]}%") if params[:search].present?
    total = suggestions.count
    suggestions = suggestions.order(source_count: :desc, updated_at: :desc).page(current_page).per(RESULTS_PER_PAGE)

    render json: { payload: suggestions.map { |s| serialize(s) }, meta: { total_count: total, page: current_page.to_i } }
  end

  def show
    render json: serialize(@faq_suggestion).merge(observations: serialize_observations(@faq_suggestion))
  end

  def update
    @faq_suggestion.update!(faq_suggestion_params)
    render json: serialize(@faq_suggestion)
  end

  # Aprova (opcionalmente com a versão editada) -> cria o conhecimento reutilizável.
  def approve
    attrs = faq_suggestion_params
    @faq_suggestion.update!(attrs) if attrs[:question].present? || attrs[:answer].present?
    Captain::AssistantResponse.create!(
      account: Current.account, assistant: @faq_suggestion.assistant,
      question: @faq_suggestion.question, answer: @faq_suggestion.answer, status: :approved
    )
    @faq_suggestion.approved!
    head :ok
  end

  def dismiss
    @faq_suggestion.dismissed!
    head :ok
  end

  private

  def scope
    Captain::FaqSuggestion.where(account: Current.account)
  end

  def set_faq_suggestion
    @faq_suggestion = scope.find(params[:id])
  end

  def valid_status?
    params[:status].present? && Captain::FaqSuggestion.statuses.key?(params[:status].to_s)
  end

  def faq_suggestion_params
    params.fetch(:faq_suggestion, {}).permit(:question, :answer)
  end

  def current_page
    params[:page] || 1
  end

  def check_authorization
    authorize(Captain::FaqSuggestion)
  end

  def serialize(suggestion)
    {
      id: suggestion.id,
      question: suggestion.question,
      answer: suggestion.answer,
      source_count: suggestion.source_count,
      language: suggestion.language,
      status: suggestion.status,
      assistant: { id: suggestion.assistant_id, name: suggestion.assistant&.name },
      created_at: suggestion.created_at.to_i,
      updated_at: suggestion.updated_at.to_i
    }
  end

  def serialize_observations(suggestion)
    suggestion.observations.includes(:conversation).order(created_at: :desc).map do |obs|
      {
        id: obs.id,
        generated_question: obs.generated_question,
        created_at: obs.created_at.to_i,
        conversation: { id: obs.conversation_id, display_id: obs.conversation&.display_id }
      }
    end
  end
end
