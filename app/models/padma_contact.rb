# encoding: UTF-8
# wrapper for PADMA-Contacts API interaction
# Configuration for LogicalModel on /config/initializers/logical_model.rb
class PadmaContact < LogicalModel

  self.hydra = Contacts::HYDRA
  self.resource_path = "/v0/contacts"
  self.attribute_keys =
    [
      :_id,
      :first_name, :last_name,
      :gender,
      :estimated_age,
      :avatar,
      :status,
      :local_status, # will only be setted if #find specifies account_name
      :local_statuses,
      :last_local_status,
      :local_teacher,
      :global_teacher_username,
      :level,
      :coefficient, # will only be setted if #find specifies account_name
      :coefficients_counts,
      :owner_name,
      :linked, # will only be setted if #find specifies account_name
      :check_duplicates,
      :email, # Primary email (contact attribute)
      :telephone, # Primary telephone (contact attribute)
      :in_active_merge
    ]
  self.has_many_keys = [:contact_attributes, :attachments]
  self.use_api_key = true
  self.api_key_name = "app_key"
  self.api_key = Contacts::API_KEY
  self.host  = Contacts::HOST

  self.enable_delete_multiple = true

  validates_presence_of :first_name
  validates_inclusion_of :gender, in: %W(male female), allow_blank: true
  validates_numericality_of :estimated_age, allow_blank: true

  validates_associated :contact_attributes
  validates_associated :attachments

  def json_root
    :contact
  end

  TIMEOUT = 5500 # miliseconds
  PER_PAGE = 9999

  VALID_LEVELS = %W(aspirante sádhaka yôgin chêla graduado asistente docente maestro)
  validates_inclusion_of :level, in: VALID_LEVELS, allow_blank: true

  VALID_STATUSES = %W(student former_student prospect)
  validates_inclusion_of :local_status, in: VALID_STATUSES, allow_blank: true
  validates_inclusion_of :status, in: VALID_STATUSES, allow_blank: true

  VALID_COEFFICIENTS = %W(unknown fp pmenos perfil pmas)
  validates_inclusion_of :coefficient, in: VALID_COEFFICIENTS, allow_blank: true

  def id
    self._id
  end

  def id= id
    self._id = id
  end

  # @return [Array<Communication>]
  def communications
    Communication.where(contact_id: self.id)
  end

  # @return [Array<Comment>]
  def comments
    Comment.where(contact_id: self.id)
  end

  # @return [Array<Communication>]
  def subscription_changes
    SubscriptionChange.where(contact_id: self.id)
  end

  # @argument [Hash] options
  # @return [Array<ActivityStream::Activity>]
  def activities(options={})
    ActivityStream::Activity.paginate(options.merge({where: {target_id: self.id, target_type: 'Contact'}}))
  end

  def linked?
    self.linked
  end

  def persisted?
    self._id.present?
  end

  ContactAttribute::AVAILABLE_TYPES.each do |type|
    define_method(type.to_s.pluralize) { self.contact_attributes.reject {|attr| !attr.is_a? type.to_s.camelize.constantize}.sort_by {|x| [x.primary ? 0 : 1, x._id]} }
  end

  def facebook_id
    self.contact_attributes.select{|attr| attr.is_a?(SocialNetworkId) && attr.category == "facebook"}.first
  end

  def mobiles
    self.contact_attributes.select{|attr| attr.is_a?(Telephone) && attr.category == "mobile"}
  end

  def non_mobile_phones
    self.contact_attributes.select{|attr| attr.is_a?(Telephone) && attr.category != "mobile"}
  end

  def former_student_at
    local_statuses.select{|s|s['value']=='former_student'}.map{|s|s['account_name']}
  end

  def prospect_at
    local_statuses.select{|s|s['value']=='prospect'}.map{|s|s['account_name']}
  end

  # Returns age in years of the contact or nil if age not available
  # @return [Integer/NilClass]
  def age
    birthday = self.date_attributes.select{|da| da.is_a_complete_birthday?}[0]
    now = Time.now.utc.to_date
    if birthday
      now.year - birthday.year.to_i - ((now.month > birthday.month.to_i || (now.month == birthday.month.to_i && now.day >= birthday.day.to_i)) ? 0 : 1)
    else
      nil
    end
  end

  def check_duplicates
    @check_duplicates || false
  end

  # @return [Array<PadmaContac>] posible duplicates of this contact
  def possible_duplicates
    possible_duplicates = []
    unless self.errors[:possible_duplicates].empty?
      self.errors[:possible_duplicates][0][0].each do |pd|
        possible_duplicates << PadmaContact.new(pd) #"#{pd["first_name"]} #{pd["last_name"]}"
      end
    end
    possible_duplicates
  end

  # Returns total amount of coefficients this contact has assigned
  # @return [ Integer ]
  def coefficients_total
    self.coefficients_counts.nil?? 0 : self.coefficients_counts.inject(0){|sum,key_value| sum += key_value[1]}
  end

  def in_active_merge?
    self.in_active_merge
  end

  # Links contact to given account
  #
  # @param [String] contact_id
  # @param [String] account_name
  #
  # returns:
  # @return false if linking failed
  # @return nil if there was a connection problem
  # @return true if successfull
  #
  # @example
  #   @contact.link_to(account)
  def self.link(contact_id, account_name)
    params = { account_name: account_name }
    params = self.merge_key(params)

    response = nil
    Timeout::timeout(self.timeout/1000) do
      response = Typhoeus::Request.post( self.resource_uri(contact_id)+"/link", :params => params, :timeout => self.timeout )
    end
    case response.code
      when 200
        log_ok response
        return true
      when 400
        log_failed response
        return false
      else
        log_failed response
        return nil
    end
  rescue Timeout::Error
    self.logger.warn "timeout"
    return nil
  end

  ##
  # Search is same as paginate but will make POST /search request instead of GET /index
  #
  # Parameters:
  #   @param options [Hash].
  #   Valid options are:
  #   * :page - indicated what page to return. Defaults to 1.
  #   * :per_page - indicates how many records to be returned per page. Defauls to 9999
  #   * all other options will be sent in :params to WebService
  #
  # Usage:
  #   Person.search(:page => params[:page])
  def self.search(options = {})
    options[:page] ||= 1
    options[:per_page] ||= 9999

    options = self.merge_key(options)

    response = Typhoeus.post(self.resource_uri+'/search', body: options)


    if response.success?
      log_ok(response)
      result_set = self.from_json(response.body)

      # this paginate is will_paginate's Array pagination
      return Kaminari.paginate_array(
          result_set[:collection],
          {
              :total_count=>result_set[:total],
              :limit => options[:per_page],
              :offset => options[:per_page] * ([options[:page], 1].max - 1)
          }
      )
    else
      log_failed(response)
      return nil
    end
  end

end
