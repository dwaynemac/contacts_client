class Email < ContactAttribute
  include ActiveModel::Validations::Callbacks

  self.attribute_keys = [:_id, :_type, :public, :primary, :category, :value, :contact_id]
  self.hydra = Contacts::HYDRA
  self.resource_path = "/v0/contact_attributes"
  self.use_api_key = true
  self.api_key_name = "app_key"
  self.api_key = Contacts::API_KEY
  self.host  = Contacts::HOST

  before_validation :strip_whitespace

  attr_accessor :category, :value, :public, :primary

  def _type
    self.class.name
  end

  validates :value, :email_format => true

  private
    def strip_whitespace
      self.value = self.value.strip
    end
end