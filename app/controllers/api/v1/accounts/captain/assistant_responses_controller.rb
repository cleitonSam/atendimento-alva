# Captain::AssistantResponse CRUD (reconstrução MIT). É a aba "FAQs" (responses) do
# Captain e o destino de uma sugestão aprovada. Mesmo contrato { payload, meta }.
class Api::V1::Accounts::Captain::AssistantResponsesController < Api::V1::Accounts::BaseController
  RESULTS_PER_PAGE = 25

  before_action :check_authorization
  before_action :set_assistant_response, only: [:show, :update, :destroy]

  def index
    responses = scope
    responses = responses.where(assistant_id: params[:assistant_id]) if params[:assistant_id].present?
    responses = responses.where('captain_assistant_responses.question ILIKE :q OR captain_assistant_responses.answer ILIKE :q',
                                q: "%#{params[:search]}%") if params[:search].present?
    total = responses.count
    responses = responses.order(updated_at: :desc).page(current_page).per(RESULTS_PER_PAGE)

    render json: { payload: responses.map { |r| serialize(r) }, meta: { total_count: total, page: current_page.to_i } }
  end

  def show
    render json: serialize(@assistant_response)
  end

  def create
    response = Captain::AssistantResponse.create!(
      response_params.merge(account: Current.account, assistant: assistant)
    )
    render json: serialize(response)
  end

  def update
    @assistant_response.update!(response_params.merge(edited: true))
    render json: serialize(@assistant_response)
  end

  def destroy
    @assistant_response.destroy!
    head :ok
  end

  private

  def scope
    Captain::AssistantResponse.where(account: Current.account)
  end

  def set_assistant_response
    @assistant_response = scope.find(params[:id])
  end

  def assistant
    Captain::Assistant.where(account: Current.account).find(params.dig(:assistant_response, :assistant_id) || params[:assistant_id])
  end

  def response_params
    params.require(:assistant_response).permit(:question, :answer)
  end

  def current_page
    params[:page] || 1
  end

  def check_authorization
    authorize(Captain::AssistantResponse)
  end

  def serialize(response)
    {
      id: response.id,
      question: response.question,
      answer: response.answer,
      status: response.status,
      edited: response.edited,
      assistant_id: response.assistant_id,
      created_at: response.created_at.to_i,
      updated_at: response.updated_at.to_i
    }
  end
end
