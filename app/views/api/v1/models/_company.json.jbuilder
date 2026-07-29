json.id resource.id
json.name resource.name
json.domain resource.domain
json.description resource.description
json.contacts_count resource.contacts_count || 0
json.additional_attributes resource.additional_attributes
json.custom_attributes resource.custom_attributes
json.thumbnail resource.avatar_url
json.last_activity_at resource.last_activity_at.to_i if resource.last_activity_at.present?
