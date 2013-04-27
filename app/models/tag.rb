class Tag < LogicalModel
  attr_accessor :name

  self.attribute_keys = [:_id, :name, :contact_ids, :account_name]

  self.hydra = Contacts::HYDRA
  self.resource_path = "/v0/tags"
  self.use_api_key = true
  self.api_key_name = "app_key"
  self.api_key = Contacts::API_KEY
  self.host  = Contacts::HOST

  validates :name, :presence => true

  def json_root
    :tag
  end

  def to_key
    [self._id]
  end

  def id
    self._id
  end

  def id= id
    self._id = id
  end


  # Returns all the tags associated with a given account
  def self.account_tags(account_name)
    params = { account_name: account_name }
    params = self.merge_key(params)


    response = nil
    Timeout::timeout(self.timeout/1000) do
      response = Typhoeus::Request.get( "#{url_protocol_prefix}#{self.host}/v0/accounts/#{account_name}/tags", :params => params, :timeout => self.timeout )
    end

    if response.code == 200
      log_ok(response)
      result_set = self.from_json(response.body)
      return result_set[:collection]
    elsif response.code == 400
      log_failed(response)
      return false
    else
      log_failed(response)
      return nil
    end
  rescue Timeout::Error
    self.logger.warn "timeout"
    return nil
  end
end