# Captain::Assistant CRUD (reconstrução MIT). Necessário para a rota :assistantId
# (onde vive a página de FAQ Suggestions) e para listar/selecionar assistentes.
class Api::V1::Accounts::Captain::AssistantsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :set_assistant, only: [:show, :update, :destroy]

  def index
    assistants = scope.order(created_at: :desc)
    render json: { payload: assistants.map { |a| serialize(a) }, meta: { total_count: assistants.size, page: 1 } }
  end

  def show
    render json: serialize(@assistant)
  end

  def create
    assistant = scope.create!(assistant_params)
    render json: serialize(assistant)
  end

  def update
    @assistant.update!(assistant_params)
    render json: serialize(@assistant)
  end

  def destroy
    @assistant.destroy!
    head :ok
  end

  private

  def scope
    Captain::Assistant.where(account: Current.account)
  end

  def set_assistant
    @assistant = scope.find(params[:id])
  end

  def assistant_params
    params.require(:assistant).permit(:name, :description, config: {})
  end

  def check_authorization
    authorize(Captain::Assistant)
  end

  def serialize(assistant)
    {
      id: assistant.id,
      name: assistant.name,
      description: assistant.description,
      config: assistant.config,
      response_guidelines: assistant.response_guidelines,
      guardrails: assistant.guardrails,
      created_at: assistant.created_at.to_i,
      updated_at: assistant.updated_at.to_i
    }
  end
end
