class Tag < LogicalModel
  attr_accessor :name

  attribute :_id
  attribute :name
  attribute :contact_ids
  attribute :account_name

  set_resource_url Contacts::HOST, "/v0/tags"

  set_api_key(:app_key,Contacts::API_KEY)

  self.hydra = Contacts::HYDRA

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
    paginate(per_page: 999, account_name: account_name)
  end

  def self.batch_add(tags, contact_ids, account_name)
    params = { account_name: account_name, tags: tags, contact_ids: contact_ids }
    params = self.merge_key(params)

    response = nil
    Timeout::timeout(self.timeout/1000) do
      response = Typhoeus::Request.post("#{url_protocol_prefix}#{self.host}/v0/accounts/#{account_name}/tags/batch_add", 
                                        :params => params, 
                                        :timeout => self.timeout)
    end

    if response.code == 201 || response.code == 202
      log_ok(response)
        return true
    elsif response.code == 400
      log_failed(response)
      ws_errors = ActiveSupport::JSON.decode(response.body)["errors"]
      ws_errors.each_key do |k|
        self.errors.add k, ws_errors[k]
      end
      return false
    else
      log_failed(response)
      return nil
    end
  rescue Timeout::Error
    self.class.logger.warn "timeout"
    return nil
  end
end
