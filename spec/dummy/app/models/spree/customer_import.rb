# == Schema Information
#
# Table name: spree_customer_imports
#
#  id                :integer          not null, primary key
#  file_file_name    :string
#  file_content_type :string
#  file_file_size    :integer
#  file_updated_at   :datetime
#  encoding          :string
#  delimer           :string
#  replace           :boolean
#  status            :integer
#  verify_result     :json
#  import_result     :json
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  proceed           :boolean
#  proceed_verified  :boolean
#  exception_message :text
#  vendor_id         :integer
#  display_name      :string
#

class Spree::CustomerImport < ActiveRecord::Base
  include Spree::Importable
  belongs_to :vendor, class_name: 'Spree::Company', foreign_key: :vendor_id, primary_key: :id
  alias_attribute :company, :vendor

  has_attached_file :file
  validates :file, presence: true
  validates_attachment_content_type :file, content_type: ["text/plain", "text/csv", "application/vnd.ms-excel"]
  validates_attachment_file_name :file, matches: [/csv\z/]

  attr_default :status, 0
  attr_default :proceed, false
  attr_default :proceed_verified, false

  def import!
    self.update_columns(status: 5)
    self.import_result = self.verify_result.map do |hash_customer|
      customer_data = hash_customer.fetch('customer')
      parent_full_account_name = hash_customer.fetch('account',{}).fetch('parent_full_account_name', '')
      account_data = hash_customer.fetch('account',{}).except('parent_full_account_name')
      bill_address_data = hash_customer.fetch('bill_address', nil)
      ship_address_data = hash_customer.fetch('ship_address', nil)
      contact_data = hash_customer.fetch('contact', nil)
      bill_address = Spree::Address.create(bill_address_data) unless bill_address_data.nil?
      ship_address = Spree::Address.create(ship_address_data) unless ship_address_data.nil?

      customer = Spree::Company.where('name ILIKE ?', customer_data['name']).first
      if customer.nil?
        customer = Spree::Company.new(customer_data)
        customer.ship_address = ship_address if ship_address
        customer.bill_address = bill_address if bill_address
      end

      if hash_customer.fetch('valid', false) && (customer.persisted? || (customer.save && (bill_address.nil? || bill_address.save) && (ship_address.nil? || ship_address.save)))
        account = nil
        if parent_full_account_name.blank?
          account = customer.vendor_accounts.create(account_data)
          account.shipping_addresses << ship_address if ship_address
          account.default_ship_address = ship_address if ship_address
          account.billing_addresses << bill_address if bill_address
          account.bill_address = bill_address if bill_address
          account.save
        else
          parent_id = customer.vendor_accounts.where(vendor_id: self.vendor_id, fully_qualified_name: parent_full_account_name).first.try(:id)
          if parent_id.present?
            account_data['parent_id'] = parent_id
            account = customer.vendor_accounts.create(account_data)
            account.shipping_addresses << ship_address if ship_address
            account.default_ship_address = ship_address if ship_address
            account.billing_addresses << bill_address if bill_address
            account.bill_address = bill_address if bill_address
            account.save
          else
            hash_customer['errors'] << "Could not find parent account #{parent_full_account_name}"
          end
        end
        unless account.nil? || account.try(:id).present?
          hash_customer['errors'] << 'Could not create Account'
          hash_customer['errors'] += account.errors.full_messages
        end

        if hash_customer['contact']
          contact = self.vendor.contacts.where(email: hash_customer['contact']['email']).first
          if contact.nil?
            contact = self.vendor.contacts.new(hash_customer['contact'])
            if contact.save
              contact.contact_accounts.create(account_id: account.id)
            else
              hash_customer['errors'] << 'Could not create contact'
              hash_customer['errors'] += contact.errors.full_messages unless contact.nil?
            end
          else
            # contact already exists so we need to link it to this account if it belongs to same company
            contact_accounts = contact.contact_accounts
            customer_id = contact_accounts.first.try(:accounts).try(:first).try(:customer_id)
            if customer_id.nil? || customer_id == account.customer_id
              contact.account_ids = [contact.account_ids, account.id].flatten.uniq
            else
              hash_customer['errors'] << 'Contact cannot belong to different customers'
              hash_customer['errors'] += contact.errors.full_messages unless contact.nil?
            end
          end
        end
        {
          customer: customer_data,
          bill_address: bill_address_data,
          ship_address: ship_address_data,
          account: account_data,
          contact: contact_data,
          imported: hash_customer.fetch('errors').blank?,
          errors: hash_customer.fetch('errors')
        }
      else
        if customer.vendor_accounts.count == 0 && customer.customer_accounts.count == 0
          customer.destroy rescue ""
          bill_address.destroy rescue ""
          ship_address.destroy rescue ""
        end
        {
          customer: customer_data,
          bill_address: bill_address_data,
          ship_address: ship_address_data,
          account: account_data,
          contact: contact_data,
          imported: false,
          errors: hash_customer.fetch('errors')
        }
      end
    end
    self.status = 6
    self.save
    Spree::ImportMailer.customers_import(self.id).deliver_now
  rescue Exception => e
    self.status = 10
    self.exception_message = e.message
    self.save
  end

  def verify!
    self.update_columns(status: 1)
    customers = []
    @companies = Hash.new(0)
    @account_fully_qualified_names = Hash.new(0)
    path = Paperclip.io_adapters.for(self.file).path
    SmarterCSV.process(path, {chunk_size: 100, col_sep: self.delimer, row_sep: :auto, convert_values_to_numeric: false, file_encoding: self.encoding}) do |chunk|
      chunk.each do |csv_customer|
        next unless csv_customer.values.any?{|value| value.present?}
        hash_customer = self.csv_to_customer(csv_customer)
        customers << self.validate_customer(hash_customer)
      end
    end
    self.verify_result = customers
    if self.verify_result.count == 0 || self.verify_result.select{|x| x['valid'] == false}.count > 0
      self.status = 3
    else
      self.status = 2
    end
    self.save
    Spree::ImportMailer.customers_verify(self.id).deliver_now
    if (self.status == 2 and self.proceed) or (self.status == 3 and self.proceed_verified)
      self.import!
    end
  rescue Exception => e
    self.status = 10
    self.exception_message = e.message
    self.save
  end

  protected

  def validate_customer(hash_customer)
    customer_data = hash_customer.fetch('customer',{})
    contact_data = hash_customer.fetch('contact', nil)

    @customer_match = nil

    @contact = self.vendor.contacts.where('email ILIKE ?', contact_data['email']).first unless contact_data.nil?
    contact_company = @contact.try(:contact_company_name)

    # find existing company that might match customer being imported
    # since we are not using the input values to match
    #   we can get rid of any @customer_match logic (point was to warn customer of match being found)
    # now, we will just do customer name AND email, then just email, then just name (and then maybe contact email)
    # define customer as or equals whatever we want to search on
    # not worried about warning them of a company with the same information

    # Find company by import params
    customer = nil
    customer ||= self.vendor.customers.where('spree_companies.name ILIKE ?', customer_data['name']).first
    customer ||= Spree::Company.where('name ILIKE ?', customer_data['name']).first
    #TODO do better matching since it is possible to have more than one company with same name
    @customer_match ||= 'complete' if customer
    # @customer_match ||= 'name' if customer

    customer ||= Spree::Company.where('email ILIKE ? AND email != ? AND email IS NOT NULL', customer_data['email'], '').first
    @customer_match ||= 'email' if customer

    # If no matches, build a new company for validation
    customer ||= Spree::Company.new(customer_data)
    # Temporarily removing restrictions
    if @customer_match == 'complete' || (@customer_match.nil? && customer.valid?)
      @companies[customer.try(:name)] += 1
    else
      if hash_customer['valid']
        hash_customer['valid'] = false
      end
      # saving the partial match we found to report to user for conflict resolution
      # customer_data['customer'] = customer.attributes if @customer_match
      hash_customer['errors'] << "Customer was found with the same #{@customer_match}" if @customer_match
      customer.errors.full_messages.each do |error_message|
        hash_customer['errors'] << "Customer: #{error_message}"
      end
    end

    account = Spree::Account.new(hash_customer['account'].except('parent_full_account_name'))
    account.skip_customer_id_verification = true
    parent_full_account_name = hash_customer.fetch('account', {}).fetch('parent_full_account_name', '')
    if parent_full_account_name.blank?
      fully_qualified_name = "#{account.try(:name).to_s}"
    else
      fully_qualified_name = "#{parent_full_account_name}:#{account.try(:name).to_s}"
    end
    @account_fully_qualified_names[fully_qualified_name] += 1
    unless account.valid?
      hash_customer['valid'] = false if hash_customer['valid']
      account.errors.full_messages.each do |error_message|
        hash_customer['errors'] << "Account: #{error_message}"
      end
    end
    if parent_full_account_name.present? \
      && @account_fully_qualified_names[parent_full_account_name] == 0 \
      && (!customer.persisted? || vendor.customer_accounts
                                        .where(
                                          fully_qualified_name: parent_full_account_name
                                        ).empty?)
      hash_customer['valid'] = false if hash_customer['valid']
      hash_customer['errors'] << "Account: Parent account must be defined before a sub account"
    elsif parent_full_account_name.present? && @account_fully_qualified_names[fully_qualified_name] > 1
      hash_customer['valid'] = false if hash_customer['valid']
      hash_customer['errors'] << "Account: Sub customer already listed with name: #{account.try(:name).to_s}"
    end
    if @account_fully_qualified_names[fully_qualified_name] > 1
      hash_customer['valid'] = false if hash_customer['valid']
      hash_customer['errors'] << "Account: invalid name, #{fully_qualified_name} is already taken"
    end
    if hash_customer['bill_address']
      bill_address = Spree::Address.new(hash_customer['bill_address'])
      unless bill_address.valid?
        hash_customer['valid'] = false if hash_customer['valid']
        bill_address.errors.full_messages.each do |error_message|
          hash_customer['errors'] << "Billing Address: #{error_message}"
        end
      end
    end
    if hash_customer['ship_address']
      ship_address = Spree::Address.new(hash_customer['ship_address'])
      unless ship_address.valid?
        hash_customer['valid'] = false if hash_customer['valid']
        ship_address.errors.full_messages.each do |error_message|
          hash_customer['errors'] << "Billing Address: #{error_message}"
        end
      end
    end
    hash_customer
  end

  def csv_to_customer(csv_customer)
    valid = true
    errors = []
    ############ Begin Match Country #############################
    bill_country = nil
    if csv_customer[:bill_country].present?
      bill_country = Spree::Country.where("name ILIKE ?", csv_customer[:bill_country]).first
      bill_country ||= Spree::Country.where("iso3 ILIKE ?", csv_customer[:bill_country]).first
      bill_country ||= Spree::Country.where("iso ILIKE ?", csv_customer[:bill_country]).first
    end
    unless bill_country || csv_customer[:bill_country].blank?
      valid = false if valid
      errors << "Billing Address: Country \"#{csv_customer[:bill_country]}\" was not recognized"
    end

    ship_country = nil
    if csv_customer[:ship_country].present?
      ship_country = Spree::Country.where("name ILIKE ?", csv_customer[:ship_country]).first
      ship_country ||= Spree::Country.where("iso3 ILIKE ?", csv_customer[:ship_country]).first
      ship_country ||= Spree::Country.where("iso ILIKE ?", csv_customer[:ship_country]).first
    end
    unless ship_country || csv_customer[:ship_country].blank?
      valid = false if valid
      errors << "Shipping Address: Country \"#{csv_customer[:ship_country]}\" was not recognized"
    end
    ############ End Match Country #############################

    ############ Begin Match States #############################
    bill_state = nil
    match_country = bill_country || ship_country || self.vendor.bill_address.try(:country) || Spree::Country.find_by_name('United States')
    if csv_customer[:bill_state].present?
      if match_country
        bill_state = match_country.states.where("name ILIKE ?", csv_customer[:bill_state]).first
        bill_state ||= match_country.states.where("abbr ILIKE ?", csv_customer[:bill_state]).first
      else
        bill_state = Spree::State.where("name ILIKE ?", csv_customer[:bill_state]).first
        bill_state ||= Spree::State.where("abbr ILIKE ?", csv_customer[:bill_state]).first
      end
      bill_country ||= bill_state.try(:country)
    end
    unless bill_state || csv_customer[:bill_state].blank?
      valid = false if valid
      errors << "Billing Address: State \"#{csv_customer[:bill_state]}\" was not recognized"
    end

    ship_state = nil
    match_country = ship_country || bill_country || self.vendor.bill_address.try(:country) || Spree::Country.find_by_name('United States')
    if csv_customer[:ship_state].present?
      if match_country
        ship_state = match_country.states.where("name ILIKE ?", csv_customer[:ship_state]).first
        ship_state ||= match_country.states.where("abbr ILIKE ?", csv_customer[:ship_state]).first
      else
        ship_state = Spree::State.where("name ILIKE ?", csv_customer[:ship_state]).first
        ship_state ||= Spree::State.where("abbr ILIKE ?", csv_customer[:ship_state]).first
      end
      ship_country ||= ship_state.try(:country)
    end
    unless ship_state || csv_customer[:ship_state].blank?
      valid = false if valid
      errors << "Shipping Address: State \"#{csv_customer[:ship_state]}\" was not recognized"
    end
    ############ End Match States #############################

    ship_zip = csv_customer[:ship_zipcode]
    if ship_zip.to_s.length >= 1 && (ship_country.try(:name) == 'United States')
      while ship_zip.length < 5
        ship_zip = "0#{ship_zip}"
      end
    end
    bill_zip = csv_customer[:bill_zipcode]
    if bill_zip.to_s.length >= 1 && (bill_country.try(:name) == 'United States')
      while bill_zip.length < 5
        bill_zip = "0#{bill_zip}"
      end
    end

    time_zone = find_time_zone(csv_customer[:'*time_zone*'], match_country.try(:name)) || ActiveSupport::TimeZone[csv_customer[:'*time_zone*'].to_s]
    time_zone = time_zone.try(:name)
    unless time_zone.present?
      time_zone = nil
      valid = false if valid
      errors << "Time zone \"#{csv_customer[:'*time_zone*']}\" was not recognized"
    end
    payment_terms = Spree::PaymentTerm.where("name ILIKE ?", csv_customer[:payment_terms]).first
    unless csv_customer[:payment_terms].blank? || csv_customer[:payment_terms] && payment_terms
      valid = false if valid
      errors << "Payment Terms \"#{csv_customer[:payment_terms]}\" was not recognized"
    end
    customer_role_id = Spree::Role.find_or_create_by(name: 'customer').id
    account_name_arr = csv_customer[:'*account_name*'].to_s.split(':')
    parent_full_account_name = account_name_arr.slice(0..-2).map{ |str| str.to_s.strip }.join(':')

    # ################# Begin User ####################
    # user_keys = [:user_first_name, :user_last_name, :user_email]
    # if user_keys.any?{|key| csv_customer[key].present? } && !user_keys.all?{|key| csv_customer[key].present? }
    #   valid = false
    #   user_errors = user_keys.map{|k| k.to_s.split('_').drop(1).join(' ') if csv_customer[k].blank? }.compact.join(', ')
    #   errors << "User is missing required fields #{user_errors}"
    # end
    # ################# End User ######################

    ################# Begin Rep ####################
    rep = nil
    rep_name = csv_customer[:sales_rep_name]
    if rep_name.present?
      initials = csv_customer[:sales_rep_initials]
      if initials.blank?
        initials = rep_name.split(' ').map{|name| name[0]}.join('').slice(0..4)
      end
      rep = self.vendor.reps.find_or_create_by(name: rep_name, initials: initials)
      unless rep.try(:persisted?)
        valid = false
        message = "Sales rep \"#{csv_customer[:sales_rep_name]}\" was not found."
        if rep.errors.full_messages.any?
          message += " Failed to create new sales rep: #{rep.errors.full_messages}"
        end
        errors << message
      end
    end
    ################# End Rep ######################

    taxable = %w[yes y true t on].include?(csv_customer[:taxable].to_s.downcase)

    company_name = csv_customer[:'*company_name*']
    company_name = account_name_arr.first.to_s.strip if company_name.blank?
    customer = {
      'name' => company_name,
      'time_zone' => time_zone
    }
    account = {
      'vendor_id' => self.vendor_id,
      'payment_terms_id' => payment_terms.try(:id),
      'name' => account_name_arr.last.try(:strip).to_s,
      'number' => csv_customer[:account_number],
      'display_name' => csv_customer[:display_name],
      'email' => csv_customer[:account_email],
      'parent_full_account_name' => parent_full_account_name,
      'rep_id' => rep.try(:id),
      'taxable' => taxable
    }
    bill_address = {
      'firstname' => csv_customer[:bill_first_name],
      'lastname' => csv_customer[:bill_last_name],
      'company' => csv_customer[:bill_company],
      'address1' => csv_customer[:bill_address1],
      'address2' => csv_customer[:bill_address2],
      'city' => csv_customer[:bill_city],
      'zipcode' => bill_zip,
      'phone' => csv_customer[:bill_phone],
      'state_id' => bill_state.try(:id),
      'country_id' => bill_country.try(:id),
      'addr_type' => "billing"
    }
    ship_address = {
      'firstname' => csv_customer[:ship_first_name],
      'lastname' => csv_customer[:ship_last_name],
      'company' => csv_customer[:ship_company],
      'address1' => csv_customer[:ship_address1],
      'address2' => csv_customer[:ship_address2],
      'city' => csv_customer[:ship_city],
      'zipcode' => ship_zip,
      'phone' => csv_customer[:ship_phone],
      'state_id' => ship_state.try(:id),
      'country_id' => ship_country.try(:id),
      'addr_type' => "shipping"
    }
    contact = {
      'first_name' => csv_customer[:contact_first_name],
      'last_name' => csv_customer[:contact_last_name],
      'email' => csv_customer[:contact_email],
      'phone' => csv_customer[:contact_phone],
      'company_id' => self.vendor_id
    }
    results = {
      'customer' => customer,
      'account' => account,
      'valid' => valid,
      'contact' => contact,
      'errors' => errors
    }
    results['bill_address'] = bill_address
    results['ship_address'] = ship_address

    if %w[first_name last_name email phone].all?{ |key| contact[key].blank? }
      results['contact'] = nil
    else
      results['contact'] = contact
    end

    results
  end

end
