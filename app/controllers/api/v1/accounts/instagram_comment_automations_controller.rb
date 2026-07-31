# CRUD das automacoes comentario->DM do Instagram (painel).
# /api/v1/accounts/:account_id/instagram_comment_automations
class Api::V1::Accounts::InstagramCommentAutomationsController < Api::V1::Accounts::BaseController
  before_action :set_automation, only: [:show, :update, :destroy]
  before_action :check_authorization

  EXCLUDED = [:handled_commenter_ids].freeze

  def index
    render json: automations.order(created_at: :desc).as_json(except: EXCLUDED)
  end

  def show
    render json: @automation.as_json(except: EXCLUDED)
  end

  def create
    automation = automations.create!(automation_params)
    render json: automation.as_json(except: EXCLUDED)
  end

  def update
    @automation.update!(automation_params)
    render json: @automation.as_json(except: EXCLUDED)
  end

  def destroy
    @automation.destroy!
    head :ok
  end

  private

  # check_authorization padrao (Api::BaseController) constantiza InstagramCommentAutomation
  # (o model existe) -> InstagramCommentAutomationPolicy.

  def automations
    Current.account.instagram_comment_automations
  end

  def set_automation
    @automation = automations.find(params[:id])
  end

  def automation_params
    params.require(:instagram_comment_automation).permit(
      :inbox_id, :name, :media_id, :keywords, :match_type, :dm_message, :dm_link,
      :dm_button_label, :public_reply, :enabled, :once_per_user, :starts_at, :ends_at
    )
  end
end
