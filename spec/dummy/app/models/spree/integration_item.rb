# == Schema Information
#
# Table name: spree_integration_items
#
#  id              :integer          not null, primary key
#  integration_key :string
#  settings        :json
#  status          :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  vendor_id       :integer
#  last_action     :text
#  last_error      :text
#  order_sync      :boolean
#  account_sync    :boolean
#  variant_sync    :boolean
#

class Spree::IntegrationItem < ActiveRecord::Base
  extend Enumerize
  include Spree::QbdIntegration::Item
  include Spree::QboIntegration::Item
  include Spree::SweetistIntegration::Item
  include Spree::ShipstationIntegration::Item
  include Spree::ShippingEasyIntegration::Item
  include Spree::ShopifyIntegration::Item
  include Spree::Integrations::ItemSharedAttributes

  before_create { self.method("#{self.integration_key}_callbacks").call.fetch(:before_create, []).each { |callback_method| self.method(callback_method).call } }
  after_create { self.method("#{self.integration_key}_callbacks").call.fetch(:after_create, []).each { |callback_method| self.method(callback_method).call } }
  after_save { self.method("#{self.integration_key}_callbacks").call.fetch(:after_save, []).each { |callback_method| self.method(callback_method).call } }
  after_update { self.method("#{self.integration_key}_callbacks").call.fetch(:after_update, []).each { |callback_method| self.method(callback_method).call } }
  after_destroy { self.method("#{self.integration_key}_callbacks").call.fetch(:after_destroy, []).each { |callback_method| self.method(callback_method).call } }
  before_destroy { self.method("#{self.integration_key}_callbacks").call.fetch(:before_destroy, []).each { |callback_method| self.method(callback_method).call } }
  belongs_to :vendor, class_name: 'Spree::Company', foreign_key: :vendor_id, primary_key: :id

  alias_attribute :company, :vendor

  has_many :integration_actions, dependent: :destroy
  has_many :integration_sync_matches, dependent: :destroy
  alias_attribute :actions, :integration_actions
  alias_attribute :matches, :integration_sync_matches

  attr_default :status, 1
  attr_default :order_sync, false
  attr_default :account_sync, false
  attr_default :variant_sync, false

  before_create { self.sales_channel ||= default_sales_channel }

  enumerize :integration_type,
            in: %w[accounting shipping sales_channel sweetist],
            predicates: true,
            scope: true

  validates :integration_type, presence: true

  SYNC_OBJECT_TYPES = %w[inventory payment product credit_memo account_payment].freeze
  FETCH_OBJECT_TYPES = %w[products customers vendors orders credit_memos account_payments].freeze
  LIMIT_SYNC_OBJECTS = %w[shipping_method payment_method].freeze

  SYNC_OBJECT_TYPES.each do |type|
    class_eval do
      define_method "should_sync_#{type}" do
        begin
          send("#{integration_key}_should_sync_#{type}")
        rescue NoMethodError
          false
        end
      end
    end
  end

  FETCH_OBJECT_TYPES.each do |type|
    class_eval do
      define_method "can_fetch_#{type}?" do
        begin
          send("#{integration_key}_can_fetch_#{type}?")
        rescue NoMethodError
          false
        end
      end
    end
  end

  def available_siblings
    company.integration_items.where.not(id: self.id)
  end

  def siblings
    available_siblings.select do |item|
      item.sales_channels_arr.include?(integration_key)
    end
  end

  def available_sales_siblings
    company.sales_integration_items.where.not(id: self.id)
  end

  def available_accounting_siblings
    company.accounting_integration_items.where.not(id: self.id)
  end

  def accounting_siblings
    available_accounting_siblings.select do |item|
      item.sales_channels_arr.include?(integration_key)
    end
  end

  def available_shipping_siblings
    company.shipping_integration_items.where.not(id: self.id)
  end

  def shipping_siblings
    available_shipping_siblings.select do |item|
      item.sales_channels_arr.include?(integration_key)
    end
  end

  def default_sales_channel
    return unless integration_settings
    integration_type = integration_settings.dig(:integration_type)
    return unless integration_type
    return unless %w[accounting shipping].include? integration_type.to_s

    [Spree::Company::SWEET_CHANNEL, Spree::Company::B2B_PORTAL_CHANNEL]
  end

  def sales_channels_arr
    sales_channel || [] rescue []
  end

  LIMIT_SYNC_OBJECTS.each do |obj|
    class_eval do
      define_method "#{obj}_ids" do
        (send("#{obj}s") || []).reject(&:blank?) rescue []
      end
      define_method "sync_all_#{obj}s?" do
        send("limit_#{obj}_by").blank?
      end
      define_method "whitelist_#{obj}s?" do
        send("limit_#{obj}_by") == 'whitelist'
      end
      define_method "blacklist_#{obj}s?" do
        send("limit_#{obj}_by") == 'blacklist'
      end
      define_method "#{obj}s_for_view" do
        return '' unless vendor
        vendor.send("#{obj}s").where(id: send("#{obj}_ids")).pluck(:name).join(', ')
      end
      define_method "limit_#{obj}s?"do
        send("#{integration_key}_limit_#{obj}s?") rescue false
      end
    end
  end

  def integration_settings
    return unless vendor
    Spree::Integration
      .available_vendors_integrations(vendor)
      .select { |i| i[:integration_key] == integration_key }.first
  end

  def name
    self.method("#{self.integration_key}_name").call rescue ''
  end

  def sales_channel_for_view
    sales_channels_arr
      .reject(&:blank?)
      .map { |e| Spree.t(e) }.join(', ')
  end

  def default_name
    Spree::Integration.available_vendors_integrations(self.company).detect do |integration|
      integration[:integration_key] == self.integration_key
    end.fetch(:name, '') rescue ''
  end

  def queue_name
    begin
      self.method("#{self.integration_key}_queue_name").call
    rescue
      'integrations'
    end
  end

  def integrationable_options_for(object)
    self.method("#{self.integration_key}_#{object.class.to_s.demodulize.underscore}_options").call(object) rescue {}
  end

  def should_sync_order(order = nil)
    self.method("#{self.integration_key}_should_sync_order").call(order) rescue self.order_sync
  end

  def should_sync_payment(payment = nil)
    self.method("#{self.integration_key}_should_sync_account_payment").call(payment) rescue false
  end
  def should_sync_account_payment(account_payment = nil)
    self.method("#{self.integration_key}_should_sync_account_payment").call(account_payment) rescue false
  end

  def should_sync_purchase_order(channel = nil)
    self.method("#{self.integration_key}_should_sync_purchase_order").call(channel) rescue false
  end

  def should_sync_variant(variant = nil)
    self.method("#{self.integration_key}_should_sync_variant").call(variant) rescue self.variant_sync
  end

  def should_sync_customer(account = nil)
    self.method("#{self.integration_key}_should_sync_customer").call(account) rescue self.account_sync
  end

  def should_sync_vendor(account = nil)
    self.method("#{self.integration_key}_should_sync_vendor").call(account) rescue self.account_sync
  end

  def should_sync_inventory(stock_transfer = nil)
    self.method("#{self.integration_key}_should_sync_inventory").call(stock_transfer) rescue self.variant_sync
  end

  def should_update_company?
    self.method("#{self.integration_key}_should_update_company?").call rescue false
  end
  def update_company_settings
    return unless should_update_company?
    begin
      self.method("#{self.integration_key}_update_company_settings").call
    rescue Exception => e
      Rails.logger e.message
    end
  end

  def incomplete_job_message
    self.method("#{self.integration_key}_incomplete_job_message").call rescue I18n.t('integrations.incomplete_job_message')
  end

  def unsynced_variants
    synced_variant_ids = self.integration_sync_matches.where(integration_syncable_type: 'Spree::Variant').where.not(sync_id: nil).pluck(:integration_syncable_id)
    self.vendor.variants_including_master.where.not(id: synced_variant_ids)
  end

  def skip_updates_from_integration(object_class)
    self.method("#{self.integration_key}_skip_updates_from_integration").call(object_class) rescue false
  end

  def sync_many_variants(all = false)
    Sidekiq::Client.push('class' => ScheduleVariantSyncWorker, 'queue' => 'integrations', 'args' => [self.id, all])
  end

  def poll
    INTEGRATIONS_SHARED_PULL_TYPES.each do |type|
      if self.try("can_poll_#{type}s?") \
        && self.try("#{type}_poll_frequency").to_i > 0 \
        && ( self.send("#{type}_last_pulled_at").blank? \
          || Time.current >= self.send("#{type}_last_pulled_at").floor(Sweet::Application.config.x.integration_rake_frequency * 60) + self.try("#{type}_poll_frequency").to_i.minutes)

        self.send("fetch_#{type}s")
      end
    end
  end

  def fetch_variants
    fetch_products
  end

  def fetch_products
    action = self.actions.find_or_create_by(
      integrationable_type: 'Spree::Variant',
      execution_log: I18n.t('integrations.pull_products.label'),
      status: 0
    )
    action.touch(:enqueued_at) unless action.created_at == action.updated_at

    Sidekiq::Client.push('class' => IntegrationWorker, 'queue' => self.queue_name, 'args' => [action.id])
  end

  def fetch_accounts
    fetch_customers
  end

  def fetch_customers
    action = self.actions.find_or_create_by(
      integrationable_type: 'Spree::Account',
      execution_log: I18n.t('integrations.pull_customers.label'),
      status: 0
    )
    action.touch(:enqueued_at) unless action.created_at == action.updated_at

    Sidekiq::Client.push('class' => IntegrationWorker, 'queue' => self.queue_name, 'args' => [action.id])
  end

  def fetch_orders
    action = self.actions.find_or_create_by(
      integrationable_type: 'Spree::Order',
      execution_log: I18n.t('integrations.pull_orders.label'),
      status: 0
    )
    action.touch(:enqueued_at) unless action.created_at == action.updated_at

    Sidekiq::Client.push('class' => IntegrationWorker, 'queue' => self.queue_name, 'args' => [action.id])
  end

  def fetch_credit_memos
    action = self.actions.find_or_create_by(
      integrationable_type: 'Spree::CreditMemo',
      execution_log: I18n.t('integrations.pull_credit_memos.label'),
      status: 0
    )
    action.touch(:enqueued_at) unless action.created_at == action.updated_at

    Sidekiq::Client.push('class' => IntegrationWorker, 'queue' => self.queue_name, 'args' => [action.id])
  end

  def fetch_account_payments
    action = self.actions.find_or_create_by(
      integrationable_type: 'Spree::AccountPayment',
      execution_log: I18n.t('integrations.pull_payments.label'),
      status: 0
    )

    Sidekiq::Client.push('class' => IntegrationWorker, 'queue' => self.queue_name, 'args' => [action.id])
  end

  # catching missing integrations
  def _execute(params, integration_url)
    { url: "#{integration_url}/edit", flash: { error: 'Missing Integration' }}
  end

  # execute method always needs to return valid URL or PATH
  def execute(method_name, params, integration_url)
    item = Spree::Integration.available_vendors_integrations(self.vendor).select {|i| i[:integration_key] == self.integration_key}.first
    available_methods = self.method("#{self.integration_key}_methods").call
    if available_methods.fetch(method_name.to_sym, false)
      self.method("#{self.integration_key}_#{method_name}").call(params, integration_url)
    else
      { url: "#{integration_url}/edit", flash: { error: 'Unauthorized integration method' }}
    end
  end

  def public_execute(method_name, request, params)
    item = Spree::Integration.available_vendors_integrations(self.vendor).select {|i| i[:integration_key] == self.integration_key}.first
    available_methods = self.method("#{self.integration_key}_public_methods").call
    if available_methods.fetch(method_name.to_sym, false)
      self.method("#{self.integration_key}_#{method_name}").call(request, params)
    else
      { data: { message: "Unauthorized integration method" } }
    end
  end

  # Queue Handling

  def start_progress_tracking
    self.stop_progress_tracking
    self.update_attributes({last_action: '', last_error: ''})
    # set enqueud as processing
    actions_to_process = self.integration_actions.where(status: [0, -3])
    Spree::IntegrationStep.where(integration_action_id: actions_to_process.ids).delete_all
    actions_to_process.update_all(status: 1)
  end

  def stop_progress_tracking
    # move processed as done
    self.integration_actions.where(status: 1).update_all(status: -3, execution_log: self.incomplete_job_message)
    self.integration_actions.where(status: 2).update_all(status: -1)
    self.integration_actions.where(status: 5).update_all(status: 10)
  end

  def progress
    progress = self.processed_count.fdiv(self.total_count) * 100
    progress.nan? ? 100 : progress.ceil
  end

  def failed_count
    self.integration_actions.where(status: [-1]).count
  end

  def waiting_count
    self.integration_actions.where(status: [0]).count
  end

  def total_count
    self.integration_actions.where(status: [1, 2, 5]).count
  end

  def processing_count
    self.integration_actions.where(status: [1]).count
  end

  def processed_count
    self.integration_actions.where(status: [2, 5]).count
  end

  def done_count
    self.integration_actions.where(status: [10]).count
  end

  def next_action
    self.integration_actions.where(status: [1]).order(:enqueued_at).first
  end

end
