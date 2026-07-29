json.payload do
  json.array! @companies do |company|
    json.partial! 'api/v1/models/company', formats: [:json], resource: company
  end
end

json.meta do
  json.count @companies_count
  json.current_page @companies.current_page
end
