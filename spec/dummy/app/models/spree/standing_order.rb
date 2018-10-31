# == Schema Information
#
# Table name: spree_standing_orders
#
#  id                            :integer          not null, primary key
#  user_id                       :integer
#  name                          :string
#  frequency_id                  :integer
#  frequency_data_1_monday       :boolean
#  frequency_data_1_tuesday      :boolean
#  frequency_data_1_wednesday    :boolean
#  frequency_data_1_thursday     :boolean
#  frequency_data_1_friday       :boolean
#  frequency_data_1_saturday     :boolean
#  frequency_data_1_sunday       :boolean
#  frequency_data_2_every        :integer
#  frequency_data_2_day_of_week  :integer
#  frequency_data_3_type         :string
#  frequency_data_3_month_number :integer
#  frequency_data_3_week_number  :integer
#  frequency_data_3_every        :integer
#  start_at                      :date
#  end_at_id                     :integer
#  end_at_data_1_after           :integer
#  end_at_data_2_by              :date
#  timing_id                     :integer
#  timing_create                 :boolean
#  timing_remind                 :boolean
#  timing_process                :boolean
#  timing_approve                :boolean
#  timing_data_create_days       :integer
#  timing_data_create_at_hour    :integer
#  timing_data_remind_days       :integer
#  timing_data_remind_at_hour    :integer
#  timing_data_process_hours     :integer
#  timing_data_process_at_hour   :integer
#  timing_data_approve_days      :integer
#  timing_data_approve_at_hour   :integer
#  total                         :decimal(, )
#  item_total                    :decimal(, )
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  account_id                    :integer
#  shipping_method_id            :integer
#  vendor_id                     :integer
#  customer_id                   :integer
#

module Spree
  class StandingOrder < Spree::Base
    include Spree::OrderRequirements

    # Date.current.wday returns Sunday: 0, Monday: 1, Tuesday: 2, ..., Saturday: 6.
    # AS.beginning_of_week uses Monday as beginning (0) and Sunday as end (7).
    # by doing WEEKDAYS[Date.current.wday], we will get desired day index to use
    # with ActiveSupport methods
    WEEKDAYS = [7, 1, 2, 3, 4, 5, 6]
    alias_attribute :line_items, :standing_line_items
    validates :name, :account_id, :shipping_method_id, presence: true
    validate :processing_days
    after_save :recalculate_dates

    belongs_to :vendor, class_name: 'Spree::Company', foreign_key: :vendor_id, primary_key: :id
    belongs_to :customer, class_name: 'Spree::Company', foreign_key: :customer_id, primary_key: :id

    belongs_to :user, class_name: 'Spree::User', foreign_key: :user_id, primary_key: :id
    belongs_to :account, class_name: 'Spree::Account', foreign_key: :account_id, primary_key: :id
    belongs_to :shipping_method, class_name: 'Spree::ShippingMethod', foreign_key: :shipping_method_id, primary_key: :id
    belongs_to :transaction_class, class_name: "Spree::TransactionClass", foreign_key: :txn_class_id, primary_key: :id

    has_many :standing_line_items, class_name: 'Spree::StandingLineItem', foreign_key: :standing_order_id, primary_key: :id, dependent: :destroy
    has_many :standing_order_schedules, class_name: 'Spree::StandingOrderSchedule', foreign_key: :standing_order_id, primary_key: :id, dependent: :destroy
    has_many :standing_order_trackers, class_name: 'Spree::StandingOrderTracker', foreign_key: :standing_order_id, primary_key: :id, dependent: :destroy
    has_many :orders, through: :standing_order_schedules, source: :order

    has_paper_trail class_name: 'Spree::Version'

    accepts_nested_attributes_for :standing_line_items
    accepts_nested_attributes_for :customer
    accepts_nested_attributes_for :vendor

    acts_as_commontable

    self.whitelisted_ransackable_associations = %w[customer vendor account standing_order_schedules]
    self.whitelisted_ransackable_attributes = %w[name frequency_id start_at]

    attr_default :start_at, Time.zone.now.to_date
    attr_default :frequency_id, 0
    attr_default :frequency_data_1_monday, false
    attr_default :frequency_data_1_tuesday, false
    attr_default :frequency_data_1_wednesday, false
    attr_default :frequency_data_1_thursday, false
    attr_default :frequency_data_1_friday, false
    attr_default :frequency_data_1_saturday, false
    attr_default :frequency_data_1_sunday, false
    attr_default :frequency_data_2_every, 1
    attr_default :frequency_data_2_day_of_week, 0
    attr_default :frequency_data_3_type, 'day'
    attr_default :frequency_data_3_month_number, 1
    attr_default :frequency_data_3_week_number, 1
    attr_default :frequency_data_3_every, 1
    attr_default :end_at_id, 0
    attr_default :end_at_data_1_after, 0
    attr_default :end_at_data_2_by, Time.zone.now.to_date
    attr_default :timing_id, 0
    attr_default :timing_remind, false
    attr_default :timing_create, false
    attr_default :timing_process, false
    attr_default :timing_approve, false
    attr_default :timing_data_remind_days, 0
    attr_default :timing_data_create_days, 0
    attr_default :timing_data_process_hours, 0
    attr_default :timing_data_process_days, 0
    attr_default :timing_data_approve_days, 0

    # problem with commontator and prepend
    def thread
      @thread ||= super
      return @thread unless @thread.nil?

      @thread = build_thread
      @thread.save if persisted?
      @thread
    end

    def self.frequency
      {
        "0" => "None",
        "1" => "Daily",
        "2" => "Weekly",
        "3" => "Monthly"
      }
    end

    def self.frequency_options
      self.frequency.to_a.map {|x| [x[1], x[0].to_i]}
    end

    def self.end_at
      {
        "0" => "Never",
        "1" => "After",
        "2" => "By"
      }
    end

    def self.end_at_options
      self.end_at.to_a.map {|x| [x[1], x[0].to_i]}
    end

    def self.frequency_type
      {
        "day" => "Day",
        "1" => "First",
        "2" => "Second",
        "3" => "Third",
        "4" => "Fourth"
      }
    end

    def self.frequency_type_options
      self.frequency_type.to_a.map {|x| [x[1], x[0]]}
    end

    def self.frequency_type_days
      {
        "1" => "1st",
        "2" => "2nd",
        "3" => "3rd",
        "4" => "4th",
        "5" => "5th",
        "6" => "6th",
        "7" => "7th",
        "8" => "8th",
        "9" => "9th",
        "10" => "10th",
        "11" => "11th",
        "12" => "12th",
        "13" => "13th",
        "14" => "14th",
        "15" => "15th",
        "16" => "16th",
        "17" => "17th",
        "18" => "18th",
        "19" => "19th",
        "20" => "20th",
        "21" => "21th",
        "22" => "22th",
        "23" => "23th",
        "24" => "24th",
        "25" => "25th",
        "26" => "26th",
        "27" => "27th",
        "28" => "28th",
        "29" => "29th",
        "30" => "30th",
        "31" => "31th",
      }
    end

    def self.frequency_type_day_options
      self.frequency_type_days.to_a.map {|x| [x[1], x[0].to_i]}
    end


    def self.days
      {
        "1" => "Monday",
        "2" => "Tuesday",
        "3" => "Wednesday",
        "4" => "Thursday",
        "5" => "Friday",
        "6" => "Saturday",
        "7" => "Sunday"
      }
    end

    def self.day_options
      self.days.to_a.map {|x| [x[1], x[0].to_i]}
    end

    def self.timing
      {
        "0" => "None",
        "1" => "Create",
        "2" => "Remind"
      }
    end

    def self.timing_options
      self.timing.to_a.map {|x| [x[1], x[0].to_i]}
    end

    def self.hour_options
      [
        { time: "0:00", hour: "12:00 am", value: 0 * 60 * 60 },
        { time: "1:00", hour: "1:00 am", value: 1 * 60 * 60 },
        { time: "2:00", hour: "2:00 am", value: 2 * 60 * 60 },
        { time: "3:00", hour: "3:00 am", value: 3 * 60 * 60 },
        { time: "4:00", hour: "4:00 am", value: 4 * 60 * 60 },
        { time: "5:00", hour: "5:00 am", value: 5 * 60 * 60 },
        { time: "6:00", hour: "6:00 am", value: 6 * 60 * 60 },
        { time: "7:00", hour: "7:00 am", value: 7 * 60 * 60 },
        { time: "8:00", hour: "8:00 am", value: 8 * 60 * 60 },
        { time: "9:00", hour: "9:00 am", value: 9 * 60 * 60 },
        { time: "10:00", hour: "10:00 am", value: 10 * 60 * 60 },
        { time: "11:00", hour: "11:00 am", value: 11 * 60 * 60 },
        { time: "12:00", hour: "12:00 pm", value: 12 * 60 * 60 },
        { time: "13:00", hour: "1:00 pm", value: 13 * 60 * 60 },
        { time: "14:00", hour: "2:00 pm", value: 14 * 60 * 60 },
        { time: "15:00", hour: "3:00 pm", value: 15 * 60 * 60 },
        { time: "16:00", hour: "4:00 pm", value: 16 * 60 * 60 },
        { time: "17:00", hour: "5:00 pm", value: 17 * 60 * 60 },
        { time: "18:00", hour: "6:00 pm", value: 18 * 60 * 60 },
        { time: "19:00", hour: "7:00 pm", value: 19 * 60 * 60 },
        { time: "20:00", hour: "8:00 pm", value: 20 * 60 * 60 },
        { time: "21:00", hour: "9:00 pm", value: 21 * 60 * 60 },
        { time: "22:00", hour: "10:00 pm", value: 22 * 60 * 60 },
        { time: "23:00", hour: "11:00 pm", value: 23 * 60 * 60 }
      ]
    end

    def order_type
      # this method mimics the attribute on Spree::Order for 'sales' or 'purchase'
      # purchase standing orders do not exisit yet, so hard coding this response
      'sales'
    end

    ###############################################
    #
    # Line Items functions
    #
    ###############################################
    def quantity
      line_items.sum(:quantity)
    end

    def currency
      self.vendor.currency
    end

    def find_standing_line_item_by_variant(variant, options = {})
      standing_line_items.detect { |standing_line_item| standing_line_item.variant_id == variant.id }
    end

    def add_many(variants, options)
      timestamp = Time.current
      Spree::Variant.where(id: variants.keys).each do |variant|
        standing_line_item = add_to_standing_line_item(variant, variants[variant.id.to_s], options)
        # options[:standing_line_item_created] = true if timestamp <= standing_line_item.created_at
      end
      self.save!
    end

    def remove(variant, quantity = 1, options = {})
      standing_line_item = remove_from_standing_line_item(variant, quantity, options)
    end

    def add_to_standing_line_item(variant, quantity, options = {})
      standing_line_item = self.standing_line_items.new(quantity: quantity, variant: variant, position: variant.position)
      standing_line_item.txn_class_id = variant.try(:txn_class_id) if variant.vendor.track_line_item_class?

      standing_line_item
    end

    def remove_from_standing_line_item(variant, quantity, options = {})
      standing_line_item = grab_standing_line_item_by_variant(variant, true, options)
      standing_line_item.quantity -= quantity

      if standing_line_item.quantity.zero?
        self.standing_line_items.destroy(standing_line_item)
      else
        standing_line_item.save!
      end

      standing_line_item
    end

    def grab_standing_line_item_by_variant(variant, raise_error = false, options = {})
      standing_line_item = self.find_standing_line_item_by_variant(variant, options)

      if !standing_line_item.present? && raise_error
        raise ActiveRecord::RecordNotFound, "Line item not found for variant #{variant.sku}"
      end

      standing_line_item
    end

    #
    # Returns total based on AVV & counts.
    #
    def calculated_total
      variant_ids = self.standing_line_items.pluck(:variant_id)
      avvs = self.account.account_viewable_variants.where(variant_id: variant_ids).to_a

      self.standing_line_items.includes(:variant).inject(0.to_d) do |sum, i|
        avv = avvs.select{|avv| avv.variant_id == i.variant_id}.first
        if avv
          sum + (avv.price * i.quantity)
        else
          sum + (i.variant.price * i.quantity)
        end
      end
    end

    alias item_total calculated_total

    #
    # Returns the maximum lead time for any variant in the order or 0 if empty
    #
    def max_lead_time
      self.standing_line_items.includes(:variant).map{|li| li.variant.lead_time}.max || 0
    end

    # Dates calculation
    #
    # Launches calculation to find first available date
    #
    def recalculate_dates(date = nil)
      if self.standing_line_items.count > 0
        date ||= Date.current
        current = date.in_time_zone(self.vendor.time_zone)
        self.standing_order_schedules.where("deliver_at > ? and created_at is null", current).update_all(visible: false)
        current_next = current
        mlt = max_lead_time

        start_next = self.start_at.in_time_zone(self.vendor.time_zone)
        # allow start_at to be the first date selected if lead_time is met based on current date
        if current_next + mlt.days > start_next
          start_next += mlt.days
        end

        if current_next > start_next
          self.calculate_next(current_next, self.vendor, self.max_lead_time)
        else
          self.calculate_next(start_next, self.vendor, self.max_lead_time)
        end
      end
    end

    # Calculates next standing_order_schedule
    #
    # In case that it's not the last schedule, launches recursion until last
    # schedule is found.
    #
    # * *Args*    :
    #   - +date+ -> last date from which it should find relative schedule
    # * *Returns* :
    #   - standing_order_schedule for specific day
    def calculate_next(date, vendor, lead_time)
      next_at = nil
      if self.frequency_id == 1
        #
        # Daily frequency:
        # is based on incrementing from tomorrow until first selected day is found
        #
        if self.frequency_data_1_days.include?(true)
          next_at = date #+ 1.day
          next_at += 1.day until self.frequency_data_1_days[WEEKDAYS[next_at.wday] - 1]
        end
      elsif self.frequency_id == 2
        #
        # Weekly frequency
        # is based on looking for beginning of week with shifting to selected
        # weekday and in case that found weekday is before current weekday
        # it will shift to next cycle.
        #
        day_index = self.frequency_data_2_day_of_week - 1
        # skip_difference = ((date.beginning_of_week.to_date - self.start_at.in_time_zone(vendor.time_zone).beginning_of_week.to_date).to_i / 7) % self.frequency_data_2_every
        # skip = self.frequency_data_2_every - (skip_difference + 1)
        next_at = date.beginning_of_week + day_index.days #+ skip.week
        if next_at < date
          next_at += self.frequency_data_2_every.weeks
        end
      elsif self.frequency_id == 3
        if self.frequency_data_3_type == "day"
          #
          # Monthly frequency with day of a month
          # is based on looking for beginning of month with shifting to selected
          # monthday and in case that found monthday is before current monthday
          # it will shift to next cycle.
          #
          # day of a month
          day_index = self.frequency_data_3_month_number - 1
          # skip_difference = (date.month - self.start_at.in_time_zone(vendor.time_zone).month) % self.frequency_data_3_every
          # skip = self.frequency_data_3_every - (skip_difference + 1)
          next_at = (date.beginning_of_month + day_index.days) #+ skip.month
          if next_at < date
            next_at += self.frequency_data_3_every.month
          end
        else
          # Monthly frequency with weekday of a month
          # is based on looking for beginning of month and selected 1st/2nd/3rd/4th
          # weekday of a month and in case that found monthday is before current
          # monthday it will shift to next cycle.
          # skip = (date.month - self.start_at.in_time_zone(vendor.time_zone).month) % self.frequency_data_3_every
          next_at = self.month_weekday_date(date, 0, self.frequency_data_3_week_number, self.frequency_data_3_type.to_i - 1)
          if next_at < date
            next_at = self.month_weekday_date(next_at, self.frequency_data_3_every, self.frequency_data_3_week_number, self.frequency_data_3_type.to_i - 1)
          end
        end
      else
        next_at = nil
      end

      # check if standing_order end_at options apply
      if next_at && ( ( self.end_at_id == 1 && self.standing_order_schedules.where(visible: true).count >= self.end_at_data_1_after ) || ( self.end_at_id == 2 && next_at >= self.end_at_data_2_by.in_time_zone(vendor.time_zone) ) )
        next_at = nil
      end
      if next_at && next_at <= (Date.current + 3.months).end_of_month
        schedule = self.standing_order_schedules.find_or_create_by(deliver_at: next_at.in_time_zone(vendor.time_zone))
        schedule.visible = true
        schedule.recalculate_dates(vendor, self, lead_time)
        schedule.save
        next_at = find_next_date(next_at)
        self.calculate_next(next_at.to_date, vendor, lead_time) if next_at
      end
    end

    def find_next_date(date)
      case self.frequency_id
      when 1
        # date
        if self.frequency_data_1_days.include?(true)
          next_at = date + 1.day
          next_at += 1.day until self.frequency_data_1_days[WEEKDAYS[next_at.wday] - 1]
          next_at
        end
      when 2
        date + self.frequency_data_2_every.weeks
      when 3
        if self.frequency_data_3_type == "day"
          date + self.frequency_data_3_every.month
        else
          self.month_weekday_date(date, self.frequency_data_3_every, self.frequency_data_3_week_number, self.frequency_data_3_type.to_i - 1)
        end
      else
        nil
      end

    end

    # Picks day of a week with skip option
    #
    # * *Args*    :
    #   - +date+ -> current date for the week
    #   - +skip+ -> the number of months it should skip
    #   - +wday+ -> the number of day in a week
    #   - +shift+ -> the number of weeks it should shift current date
    # * *Returns* :
    #   - date for specific skipped weekday in a month
    def month_weekday_date(date, skip, wday, week_shift)
      calc_next_at = (date.beginning_of_month) + skip.month#+ skip.month
      calc_next_at += 1.day until WEEKDAYS[calc_next_at.wday] == wday # find 1st selected weekday in a month
      calc_next_at = calc_next_at + week_shift.week # shifts to 1st/2nd/3rd/4th week
      calc_next_at
    end

    #
    # Standing Order Tracking
    #
    def start_tracking!
      if self.id && self.standing_order_trackers.where(active: true).empty?
        standing_json = {
          standing_order: self,
          standing_line_items: self.standing_line_items
        }.to_json
        tracker = self.standing_order_trackers.create(tracking_since: Time.current, original: standing_json)
        StandingOrderTrackingWorker.perform_in(30.minutes, tracker.id)
      end
    end

    def end_string
      case self.end_at_id
      when 0
        "Never."
      when 1
        "After #{self.end_at_data_1_after} occurrences."
      when 2
        "By #{DateHelper.sweet_date(self.end_at_data_2_by, self.vendor.try(:time_zone))}."
      end
    end

    def frequency_string
      case self.frequency_id
      when 0
        "None."
      when 1
        days = []
        days << "Monday" if self.frequency_data_1_monday
        days << "Tuesday" if self.frequency_data_1_tuesday
        days << "Wednesday" if self.frequency_data_1_wednesday
        days << "Thursday" if self.frequency_data_1_thursday
        days << "Friday" if self.frequency_data_1_friday
        days << "Saturday" if self.frequency_data_1_saturday
        days << "Sunday" if self.frequency_data_1_sunday
        "Daily each #{days.to_sentence}."
      when 2
        "Weekly every #{self.frequency_data_2_every} week(s) on #{Spree::StandingOrder.days[self.frequency_data_2_day_of_week.to_s]}."
      when 3
        if self.frequency_data_3_type == "day"
          "Monthly each #{Spree::StandingOrder.frequency_type_days[self.frequency_data_3_month_number.to_s]} every #{self.frequency_data_3_every} month(s)."
        else
          "Monthly each #{Spree::StandingOrder.frequency_type[self.frequency_data_3_type.to_s]} #{Spree::StandingOrder.days[self.frequency_data_3_week_number.to_s]} every #{self.frequency_data_3_every} month(s)."
        end
      end
    end

    def timing_string
      case self.timing_id
      when 0
        "None."
      when 1
        create_hour = Spree::StandingOrder.hour_options.select {|o| o[:value] == self.timing_data_create_at_hour}.first.fetch(:hour, nil)
        create = "Create #{self.timing_data_create_days} day(s) in advance at #{create_hour}"
        if self.timing_process
          process_hour = Spree::StandingOrder.hour_options.select {|o| o[:value] == self.timing_data_process_hours}.first.fetch(:time, nil)
          create << " and process #{process_hour} hour(s) before cut-off time"
        end
        create << "."
        create
      when 2
        remind_hour = Spree::StandingOrder.hour_options.select {|o| o[:value] == self.timing_data_remind_at_hour}.first.fetch(:hour, nil)
        remind = "Remind #{self.timing_data_remind_days} day(s) in advance at #{remind_hour}."
      end
    end

    def account_handle
      self.account.fully_qualified_name
    end

    def frequency_data_1_days
      [
        self.frequency_data_1_monday,
        self.frequency_data_1_tuesday,
        self.frequency_data_1_wednesday,
        self.frequency_data_1_thursday,
        self.frequency_data_1_friday,
        self.frequency_data_1_saturday,
        self.frequency_data_1_sunday
      ]
    end

    def upcoming_schedules
      self.standing_order_schedules.where("visible = true and deliver_at > ? and skip != ?", Date.current.in_time_zone(self.vendor.time_zone), true).order(:deliver_at)
    end

    def upcoming_schedules_including_skipped
      self.standing_order_schedules.where("visible = true and deliver_at > ?", Date.current.in_time_zone(self.vendor.time_zone)).order(:deliver_at)
    end

    def next_schedule
      upcoming_schedules.first
    end

    def add_lines_to_order(order)
      variants = Hash[
        self.standing_line_items.map.with_index do |item, idx|
          var_hash = { quantity: item.quantity, pack_size: item.pack_size, lot_number: item.lot_number, position: item.position}
          if order.vendor.track_line_item_class?
            transfer_class = item.try(:txn_class_id) ? item.try(:txn_class_id) : item.variant.try(:txn_class_id)
            var_hash.merge!({txn_class_id: transfer_class })
          end
          ["#{item.variant_id}_#{idx}", var_hash]
        end
      ]
      order.contents.add_many(variants, {})
    end

    def create_clone!
      so = self.clone
      so.save!

      so
    end

    def clone
      so = self.dup
      so.name = "#{self.name} (#{Spree.t(:clone)})".strip
      self.standing_line_items.each do |line|
        so.standing_line_items << line.dup
      end

      so
    end

    private

    def processing_days
      if timing_process && timing_data_process_days.to_i > timing_data_create_days.to_i
        self.errors.add(:base, "Must process with the same or fewer days as the order is created")
        return false
      end
      true
    end

  end
end
