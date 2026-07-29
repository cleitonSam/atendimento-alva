# Drop Liquid para expor a política de SLA em templates (ex.: automações).
# Reconstruído em MIT.
class SlaPolicyDrop < BaseDrop
  def name
    @obj.try(:name)
  end

  def description
    @obj.try(:description)
  end
end
