json.audit_logs do
  json.array! @audit_logs do |audit|
    json.id audit.id
    json.action audit.action
    json.auditable_type audit.auditable_type
    json.auditable_id audit.auditable_id
    json.associated_type audit.associated_type
    json.associated_id audit.associated_id
    json.user_id audit.user_id
    json.user_type audit.user_type
    json.username audit.username
    json.audited_changes audit.audited_changes
    json.version audit.version
    json.remote_address audit.remote_address
    json.created_at audit.created_at.to_i
  end
end

json.current_page @audit_logs.current_page
json.total_entries @audit_logs_count
