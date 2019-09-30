class Telephone < ContactAttribute
  include ActiveModel::Validations::Callbacks
  before_validation :strip_whitespace

  self.attribute_keys = [:_id, :_type, :public, :primary, :category, :value, :contact_id]
  self.hydra = Contacts::HYDRA
  self.resource_path = "/v0/contact_attributes"
  self.use_api_key = true
  self.api_key_name = "app_key"
  self.api_key = Contacts::API_KEY
  self.host  = Contacts::HOST

  attr_accessor :category, :value, :public, :primary

  validates :value, format: { with: /\A[\(|\d|+][\d| |\)\-|\.]{6,16}.*\d\z/ },
                    length: { maximum: 45 }

  def masked?
    value.present? && value.last == '#'
  end

  def _type
    self.class.name
  end

  private
    def strip_whitespace
      self.value = self.value.strip
    end
end
