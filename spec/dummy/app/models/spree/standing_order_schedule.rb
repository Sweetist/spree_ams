# == Schema Information
#
# Table name: spree_standing_order_schedules
#
#  id                :integer          not null, primary key
#  standing_order_id :integer
#  order_id          :integer
#  deliver_at        :datetime
#  remind_at         :datetime
#  reminded_at       :datetime
#  create_at         :datetime
#  created_at        :datetime
#  process_at        :datetime
#  processed_at      :datetime
#  skip              :boolean
#  visible           :boolean
#

module Spree
  class StandingOrderSchedule < Spree::Base

    belongs_to :standing_order, class_name: 'Spree::StandingOrder', foreign_key: :standing_order_id, primary_key: :id
    belongs_to :order, class_name: 'Spree::Order', foreign_key: :order_id, primary_key: :id

    attr_default :skip, false
    attr_default :visible, true

    self.whitelisted_ransackable_associations = %w[standing_order order]
    self.whitelisted_ransackable_attributes = %w[deliver_at create_at process_at remind_at]

    def self.unprocessed
      where(processed_at: nil).where.not(process_at: nil, created_at: nil)
    end
    # Disable automatic created_at & udpated_at
    #
    # We always recreate objects so we don't need to track when they where
    # created or updated. Created_at refers to timestamp of created order
    def record_timestamps
      false
    end

    def generate_order!
      if self.order
        self.created_at = order.created_at if self.created_at.nil?
        self.save
        return []
      end
      errors = []
      if self.standing_order.standing_line_items.count > 0
        order = Spree::Order.new(
          delivery_date: DateHelper.sweet_date(self.deliver_at, self.standing_order.vendor.time_zone),
          vendor_id: self.standing_order.vendor_id,
          account_id: self.standing_order.account_id,
          customer_id: self.standing_order.customer_id,
          user_id: self.standing_order.user_id,
          created_by_id: self.standing_order.user_id,
          ship_address_id: self.standing_order.account.try(:default_ship_address_id),
          bill_address_id: self.standing_order.account.try(:bill_address_id),
          shipping_method_id: self.standing_order.shipping_method_id
        )

        order.set_email
        if standing_order.try(:vendor).try(:track_order_class?)
          order.txn_class_id = standing_order.try(:txn_class_id)
          order.txn_class_id ||= standing_order.account.try(:default_txn_class_id)
        end

        if order.save
          errors = self.standing_order.add_lines_to_order(order)
          begin
            order.recalculate_shipping_rates if order.active_shipping_calculator
          rescue Spree::ShippingError
          end
          self.order = order
          if errors.present?
            Spree::OrderMailer.so_create_error_email(order.id, self.standing_order.name, false, errors).deliver_later
          elsif !self.standing_order.timing_process
            Spree::OrderMailer.so_create_email(order.id, self.standing_order.name).deliver_later
          end
          self.created_at = Time.current.in_time_zone(self.standing_order.vendor.time_zone)
        end
      end
      self.save
      errors
    end

    def process_order!
      errors = []
      if self.order.nil?
        errors = self.generate_order!
      end
      order = self.order
      if errors.empty?
        return ['Unable to find order'] unless order
        order.update_columns(recalculate_shipping: false)
        if States[order.state] > States['cart']
          self.processed_at = order.completed_at if self.processed_at.nil?
        elsif order.is_valid? && order.errors_from_order_rules.blank? && order.next && order.errors.full_messages.empty?# move order to next stage.
          self.processed_at = Time.current.in_time_zone(self.standing_order.vendor.time_zone)
        elsif order
          errors += order.errors.full_messages
          order.errors_from_order_rules.each { |e| errors << e }
          order.line_items.each do |li|
            if li.errors.full_messages.present?
              errors += ["#{li.item_name}: #{li.errors.full_messages.join('; ')}"]
            end
          end
          Spree::OrderMailer.so_process_error_email(order.id, self.standing_order.name, errors).deliver_later
          self.processed_at = Time.current.in_time_zone(self.standing_order.vendor.time_zone)
        end
      end

      self.save
      if errors.present?
        errors.each do |error|
          self.errors.add(:base, error)
        end
        return false
      end

      true
    end

    def remind!
      Spree::StandingOrderMailer.reminder_email(self.id).deliver_later
      self.reminded_at = Time.current.in_time_zone(self.standing_order.vendor.time_zone)
      self.save
    end

    def next
      self.standing_order.standing_order_schedules.where("deliver_at > ? and visible = true and skip = false", self.deliver_at).order("deliver_at asc").first
    end

    def previous
      self.standing_order.standing_order_schedules.where("deliver_at < ? and visible = true and skip = false", self.deliver_at).order("deliver_at desc").first
    end

    def recalculate_dates(vendor, standing_order, lead_time)
      if self.visible && self.order.nil?
        self.create_at = nil unless self.created_at
        self.process_at = nil unless self.processed_at
        self.remind_at = nil unless self.reminded_at
        if standing_order.timing_id == 1
          raw_create_at = self.deliver_at.in_time_zone(vendor.time_zone) - lead_time.days - standing_order.timing_data_create_days.days
          self.create_at = raw_create_at.change(hour: standing_order.timing_data_create_at_hour/60/60)
          if standing_order.timing_process
            cutoff_time = vendor.order_cutoff_time.in_time_zone(vendor.time_zone)
            raw_process_at = self.deliver_at.in_time_zone(vendor.time_zone) - lead_time.days - standing_order.timing_data_process_days.to_i.days
            self.process_at = raw_process_at.change(hour: ((cutoff_time - cutoff_time.beginning_of_day) - standing_order.timing_data_process_hours)/60/60)
          end
        elsif standing_order.timing_id == 2
          raw_remind_at = self.deliver_at.in_time_zone(vendor.time_zone) - lead_time.days - standing_order.timing_data_remind_days.days
          self.remind_at = raw_remind_at.change(hour: standing_order.timing_data_remind_at_hour/60/60)
        end
      end
    end

    def will_perform?(action)
      action = action.to_s
      !!(self.method("#{action}_at").call && self.method("#{action.ends_with?('e') ? action[0..-2] : action}ed_at").call.nil?)
    end

  end
end
