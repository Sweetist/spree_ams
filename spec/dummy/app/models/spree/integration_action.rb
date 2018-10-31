require 'aws-sdk-s3'
# == Schema Information
#
# Table name: spree_integration_actions
#
#  id                   :integer          not null, primary key
#  integrationable_id   :integer
#  integrationable_type :string
#  integration_item_id  :integer
#  status               :integer
#  execution_log        :text
#  execution_count      :integer
#  enqueued_at          :datetime
#  processed_at         :datetime
#

class Spree::IntegrationAction < ActiveRecord::Base
  include Spree::QbdIntegration::Action
  include Spree::QboIntegration::Action
  include Spree::SweetistIntegration::Action
  include Spree::ShipstationIntegration::Action
  include Spree::ShippingEasyIntegration::Action
  include Spree::ShopifyIntegration::Action
  include Spree::PushToWombat

  belongs_to :integrationable, polymorphic: true
  belongs_to :integration_item
  has_many :integration_sync_matches, through: :integration_item, source: :integration_sync_matches
  has_many :integration_steps, class_name: 'Spree::IntegrationStep', foreign_key: :integration_action_id, primary_key: :id, dependent: :destroy
  has_one :current_step, -> { where(is_current: true) }, class_name: 'Spree::IntegrationStep', foreign_key: :integration_action_id, primary_key: :id

  delegate :vendor, to: :integration_item

  alias_attribute :company, :vendor

  attr_default :status, 0
  attr_default :enqueued_at, lambda { Time.current }
  attr_default :execution_count, 0

  def trigger!
    delete_steps
    touch(:last_response_time)
    result = execute_action
    reload
    return if status > 1
    update_execution_log(result)
    return if status >= 0
    integration_sync_match.try(:update_columns, no_sync: false)
    return if execution_count >= 10
    enqueue_again if try("#{integration_item.integration_key}_retry")
  end

  def integration_sync_match
    integration_sync_matches.find_by(integration_syncable: integrationable)
  end

  def allow_execute?
    return true unless integrationable
    result, reason = integrationable.sync_for_item(integration_item)
                                    .values_at(:result, :reason)
    return true if result == true
    update_execution_log(status: 11,
                         log: I18n.t('integrations.action_skipped',
                                     reason: reason))
    integration_sync_match.try(:update!, no_sync: false)
    false
  end

  def name_for_log
    name = integrationable.try(:name_for_integration)
    name = "#{sync_type} - #{sync_fully_qualified_name}".strip if name.blank?
    name = '' if name == '-'
    name = execution_log if name.blank?

    # return "#{name}. #{execution_log}" if [-1, -2, 3, 11].include? status
    name
  end

  def next_integration_step
    next_step = nil
    if self.current_step.presence
      next_step = self.current_step.sub_steps.incomplete.order([position: :desc, id: :desc]).first
    end

    next_step || self.integration_steps.order([position: :desc, id: :desc]).incomplete.first
  end

  def set_current_step(step = nil)
    step ||= next_integration_step
    integration_steps.update_all(is_current: false)
    step.is_current = true
    step.save!
  end


  def status_text
    case status
    when -10
      'dead'
    when -3
      'retry'
    when -2
      'failed'
    when -1
      'failed'
    when 0
      'enqueud'
    when 1
      'processing'
    when 2
      'failing'
    when 3
      'processed'
    when 5
      'processed'
    when 10
      'done'
    when 11
      'skipped'
    end
  end

  def status_color
    case status
    when -10
      'danger'
    when -3
      'info'
    when -2
      'danger'
    when -1
      'danger'
    when 0
      'info'
    when 1
      'info'
    when 2
      'danger'
    when 3
      'warning'
    when 5
      'success'
    when 10
      'success'
    when 11
      'info'
    end
  end

  def update_execution_log(result)
    return unless result && result.respond_to?(:fetch)

    self.status = result.fetch(:status)
    self.execution_count += 1 if result.fetch(:status) != 0
    self.execution_log = result.fetch(:log)
    self.execution_backtrace = result.dig(:backtrace)
    self.sidekiq_jid = result.dig(:sidekiq_jid)
    self.integrationable = result.dig(:integrationable) if result.dig(:integrationable)
    self.processed_at = Time.current if result.fetch(:status) != 0
    self.last_response_time = Time.current
    save!
  end

  def delete_steps
    if status == -1
      self.update_columns(step: nil)
      self.integration_steps.delete_all
    end
  end

  def push_to_sidekiq(delay = 10.seconds)
    Sidekiq::Client.push(
      'at' => Time.current.to_i + delay,
      'class' => IntegrationWorker,
      'queue' => integration_item.queue_name,
      'args' => [id]
    )
  end

  def prevent_restart
    log_message = [execution_log.to_s, I18n.t('integrations.action.new_action_prevents_restart')].join(' --- ')
    update_columns(status: -2, execution_log: log_message)
  end

  def update_previously_failed_actions
    Spree::IntegrationAction.where(integrationable: integrationable,
                                   integration_item: integration_item,
                                   status: -1).each(&:prevent_restart)
  end

  private

  def restart_dead_job
    job = Sidekiq::DeadSet.new.find_job(sidekiq_jid)
    return { status: -1, log: I18n.t('integrations.not_found_JID') } unless job
    job.retry
    { status: 11, log: I18n.t('integrations.restarted_as_new_action') }
  end

  def execute_action
    return unless allow_execute?
    update_previously_failed_actions
    return restart_dead_job if sidekiq_jid
    method("#{integration_item.integration_key}_trigger")
      .call(integrationable_id, integrationable_type, self)
  rescue Exception => e
    { status: -1, log: e.message, backtrace: e.backtrace }
  end

  def enqueue_again
    update_columns(status: 0, enqueued_at: Time.current)
    Sidekiq::Client.push(
      'at' => Time.current.to_i + (execution_count.to_i + 1).minutes,
      'class' => IntegrationWorker,
      'queue' => integration_item.queue_name,
      'args' => [id]
    )
  end
end
