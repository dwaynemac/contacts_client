class HistoryEntry < LogicalModel
  use_hydra Contacts::HYDRA

  set_resource_url Contacts::HOST,'/v0/history_entries'
  set_api_key :app_key, Contacts::API_KEY

  attribute :_id
  attribute :historiable_type
  attribute :historiable_id
  attribute :contact_id
  attribute :attribute
  attribute :old_value
  attribute :changed_at

  def contact_id
    self.historiable_id
  end
end

