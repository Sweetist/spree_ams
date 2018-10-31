# == Schema Information
#
# Table name: spree_vendor_imports
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
#  company_id         :integer
#

class Spree::VendorImport < ActiveRecord::Base
  include Spree::Importable
  belongs_to :company, class_name: 'Spree::Company', foreign_key: :company_id, primary_key: :id

  validates :file, presence: true
  has_attached_file :file
  validates_attachment_content_type :file, content_type: 'text/csv'
  validates_attachment_file_name :file, matches: [/csv\z/]

  attr_default :status, 0
  attr_default :proceed, false
  attr_default :proceed_verified, false

  def import!
    self.update_columns(status: 5)
    self.import_result = self.verify_result.map do |hash_vendor|
      vendor_data = hash_vendor.fetch('vendor')
      account_data = hash_vendor.fetch('account',{})
      bill_address_data = hash_vendor.fetch('bill_address', nil)

      bill_address = Spree::Address.create(bill_address_data) unless bill_address_data.nil?
      vendor = company.vendor_accounts.where('name ILIKE ?', vendor_data['name']).first.try(:vendor)

      if vendor.nil?
        vendor = Spree::Company.new(vendor_data)
        vendor.bill_address = bill_address if bill_address
        vendor.currency = self.company.currency
        vendor.receive_orders = true
      end
      if hash_vendor.fetch('valid', false) && (vendor.persisted? || (vendor.save && (bill_address.nil? || bill_address.save)))
        account = nil

        account = vendor.customer_accounts.create(account_data)
        account.billing_addresses << bill_address if bill_address
        account.skip_name_verification = true
        if account.save
          account.create_default_stock_location
        end
        {
          vendor: vendor_data,
          bill_address: bill_address_data,
          account: account_data,
          imported: hash_vendor.fetch('errors').blank?,
          errors: hash_vendor.fetch('errors')
        }
      else
        if vendor.customer_accounts.blank? && vendor.vendor_accounts.blank?
          vendor.destroy rescue ""
          bill_address.destroy rescue ""
        end
        {
          vendor: vendor_data,
          bill_address: bill_address_data,
          account: account_data,
          imported: false,
          errors: hash_vendor.fetch('errors')
        }
      end
    end
    self.status = 6
    self.save
    Spree::ImportMailer.vendors_import(self.id).deliver_now
  rescue Exception => e
    self.status = 10
    self.exception_message = e.message
    self.save
  end

  def verify!
    self.update_columns(status: 1)
    vendors = []
    @vendors = Hash.new(0)
    path = Paperclip.io_adapters.for(self.file).path
    SmarterCSV.process(path, {chunk_size: 100, col_sep: self.delimer, row_sep: :auto, convert_values_to_numeric: false, file_encoding: self.encoding}) do |chunk|
      chunk.each do |csv_vendor|
        next unless csv_vendor.values.any?{|value| value.present?}
        hash_vendor = self.csv_to_vendor(csv_vendor)
        vendors << self.validate_vendor(hash_vendor)
      end
    end
    self.verify_result = vendors
    if self.verify_result.count == 0 || self.verify_result.select{|x| x['valid'] == false}.count > 0
      self.status = 3
    else
      self.status = 2
    end
    self.save
      Spree::ImportMailer.vendors_verify(self.id).deliver_now
    if (self.status == 2 and self.proceed) or (self.status == 3 and self.proceed_verified)
      self.import!
    end
  rescue Exception => e
    self.status = 10
    self.exception_message = e.message
    self.save
  end

  protected

  def validate_vendor(hash_vendor)
    vendor_data = hash_vendor.fetch('vendor',{})
    account = hash_vendor.fetch('account', {})
    account['name']
    account['']

    vendor = self.company.vendor_accounts.where('name ILIKE ?', vendor_data['name']).first.try(:vendor)
    vendor ||= Spree::Company.new(vendor_data)

    @vendors[vendor.name] += 1

    if @vendors[vendor.name] > 1
      hash_vendor['valid'] = false
      hash_vendor['errors'] << "Duplicate vendor name found: #{vendor.name}"
    end
    if self.company.customer_accounts.where(name: vendor.name).present?
      hash_vendor['valid'] = false
      hash_vendor['errors'] << "Cannot use the same vendor name as a customer: #{vendor.name}"
    end

    if vendor.valid?
      account = Spree::Account.new(hash_vendor['account'])
      account.skip_vendor_id_verification = true
      unless account.valid?
        hash_vendor['valid'] = false
        account.errors.full_messages.each do |error_message|
          hash_vendor['errors'] << "Vendor Error: #{error_message}"
        end
      end
    else
      hash_vendor['valid'] = false
      vendor.errors.full_messages.each do |error_message|
        hash_vendor['errors'] << "Vendor Error: #{error_message}"
      end
    end

    if hash_vendor['bill_address']
      bill_address = Spree::Address.new(hash_vendor['bill_address'])
      unless bill_address.valid?
        hash_vendor['valid'] = false if hash_vendor['valid']
        bill_address.errors.full_messages.each do |error_message|
          hash_vendor['errors'] << "Billing Address: #{error_message}"
        end
      end
    end
    hash_vendor
  end

  def csv_to_vendor(csv_vendor)

    valid = true
    errors = []
    ############ Begin Match Country #############################
    bill_country = nil
    if csv_vendor[:bill_country].present?
      bill_country = Spree::Country.where("name ILIKE ?", csv_vendor[:bill_country]).first
      bill_country ||= Spree::Country.where("iso3 ILIKE ?", csv_vendor[:bill_country]).first
      bill_country ||= Spree::Country.where("iso ILIKE ?", csv_vendor[:bill_country]).first
    end
    unless bill_country || csv_vendor[:bill_country].blank?
      valid = false if valid
      errors << "Billing Address: Country \"#{csv_vendor[:bill_country]}\" was not recognized"
    end

    ############ Begin Match States #############################
    bill_state = nil
    match_country = bill_country || self.company.bill_address.try(:country) || Spree::Country.find_by_name('United States')
    if csv_vendor[:bill_state].present?
      if match_country
        bill_state = match_country.states.where("name ILIKE ?", csv_vendor[:bill_state]).first
        bill_state ||= match_country.states.where("abbr ILIKE ?", csv_vendor[:bill_state]).first
      else
        bill_state = Spree::State.where("name ILIKE ?", csv_vendor[:bill_state]).first
        bill_state ||= Spree::State.where("abbr ILIKE ?", csv_vendor[:bill_state]).first
      end
    end
    unless bill_state || csv_vendor[:bill_state].blank?
      valid = false if valid
      errors << "Billing Address: State \"#{csv_vendor[:bill_state]}\" was not recognized"
    end

    bill_zip = csv_vendor[:bill_zipcode]
    if bill_zip.to_s.length >= 1 && (bill_country.try(:name) == 'United States' || bill_state.try(:country).try(:name) == 'United States')
      while bill_zip.length < 5
        bill_zip = "0#{bill_zip}"
      end
    end
    time_zone = find_time_zone(csv_vendor[:'*time_zone*'], match_country.try(:name)) || ActiveSupport::TimeZone[csv_vendor[:'*time_zone*'].to_s]
    time_zone = time_zone.try(:name)
    unless time_zone.present?
      time_zone = nil
      valid = false if valid
      errors << "Time zone \"#{csv_vendor[:'*time_zone*']}\" was not recognized"
    end
    payment_terms = Spree::PaymentTerm.where("name ILIKE ?", csv_vendor[:payment_terms]).first
    unless csv_vendor[:payment_terms].blank? || csv_vendor[:payment_terms] && payment_terms
      valid = false if valid
      errors << "Payment Terms \"#{csv_vendor[:payment_terms]}\" was not recognized"
    end

    # taxable = %w[yes y true t on].include?(csv_vendor[:taxable].to_s.downcase)

    company_name = csv_vendor[:'*vendor_name*']
    # company_name = parent_vendor_name if company_name.blank?
    # company_name = vendor_name_arr.first.try(:strip).to_s if company_name.blank?

    vendor = {
      'name' => csv_vendor[:'*vendor_name*'],
      'time_zone' => time_zone
    }
    account = {
      'customer_id' => self.company_id,
      'payment_terms_id' => payment_terms.try(:id),
      'name' => csv_vendor[:'*vendor_name*'],
      'number' => csv_vendor[:account_number],
      'email' => csv_vendor[:vendor_email]
    }
    bill_address = {
      'firstname' => csv_vendor[:bill_first_name],
      'lastname' => csv_vendor[:bill_last_name],
      'company' => csv_vendor[:bill_company],
      'address1' => csv_vendor[:bill_address1],
      'address2' => csv_vendor[:bill_address2],
      'city' => csv_vendor[:bill_city],
      'zipcode' => csv_vendor[:bill_zipcode],
      'phone' => csv_vendor[:bill_phone],
      'state_id' => bill_state.try(:id),
      'country_id' => bill_country.try(:id),
      'addr_type' => "billing"
    }
    results = {
      'vendor' => vendor,
      'account' => account,
      'bill_address' => bill_address,
      'valid' => valid,
      'errors' => errors
    }

    results
  end
end
