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
    old_file_id = @automation.dm_image_file_id
    @automation.update!(automation_params)
    # trocou a imagem de capa -> apaga a antiga no ImageKit
    cleanup_image(old_file_id) if old_file_id.present? && old_file_id != @automation.dm_image_file_id
    render json: @automation.as_json(except: EXCLUDED)
  end

  def destroy
    file_id = @automation.dm_image_file_id
    @automation.destroy!
    cleanup_image(file_id)
    head :ok
  end

  # Assinatura pro upload client-side do ImageKit (mesma do estudio de publicacao).
  def imagekit_auth
    result = Imagekit::AuthService.new.perform
    if result[:error]
      render json: { error: result[:error] }, status: :unprocessable_entity
    else
      render json: result
    end
  end

  private

  def cleanup_image(file_id)
    Imagekit::DeleteFilesJob.perform_later([file_id]) if file_id.present?
  end

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
      :dm_button_label, :public_reply, :enabled, :once_per_user, :starts_at, :ends_at,
      :dm_image_url, :dm_image_file_id, :dm_card_title,
      dm_buttons: [:title, :url]
    )
  end
end
