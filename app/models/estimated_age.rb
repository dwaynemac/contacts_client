class EstimatedAge < ContactAttribute
  self.attribute_keys = [:_id, :_type, :public, :primary, :value, :contact_id]
  self.hydra = Contacts::HYDRA
  self.resource_path = "/v0/contact_attributes"
  self.use_api_key = true
  self.api_key_name = "app_key"
  self.api_key = Contacts::API_KEY
  self.host  = Contacts::HOST

  attr_accessor :value, :public, :primary

  def _type
    self.class.name
  end

  validates_numericality_of :value
end