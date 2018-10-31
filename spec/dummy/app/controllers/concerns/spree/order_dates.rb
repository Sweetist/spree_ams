module Spree::OrderDates
  extend ActiveSupport::Concern

  def get_num_until_next_available_day(days_available = [], options = {})
    blackout_days = days_available[0]
    next_available_day = Time.current.in_time_zone(current_company.time_zone).to_date
    num_days = 0

    account = options[:account]
    order = options[:order]
    account ||= order.try(:account)

    if blackout_days != "0,1,2,3,4,5,6"
      if account
        if account.vendor.hard_lead_time
          num_days += order.try(:max_lead_time) || account.min_lead_days
        end
        num_days += 1 if account.vendor.hard_cutoff_time && account.after_cutoff?

        next_available_day += num_days.days
      else
        num_days = 1
        next_available_day += 1.day  #set next available to tomorrow
      end

      while(blackout_days.include? next_available_day.wday.to_s)
        next_available_day += 1.day
        num_days += 1
      end
    end

    ["#{num_days}d", next_available_day]
  end

  def generate_days(account)
    @account = account
    days_to_blackout = ""
    day_tracker = []
    availability_message = "Vendor only delivers on "
    deliverable_days = @account.deliverable_days
    if deliverable_days["0"] && deliverable_days["6"] && !deliverable_days["1"] && !deliverable_days["2"] && !deliverable_days["3"] && !deliverable_days["4"] && !deliverable_days["5"]
      availability_message = "Vendor only delivers on weekends"
      days_to_blackout = "1,2,3,4,5"
    elsif !deliverable_days["0"] && !deliverable_days["6"] && deliverable_days["1"] && deliverable_days["2"] && deliverable_days["3"] && deliverable_days["4"] && deliverable_days["5"]
      availability_message = "Vendor only delivers on weekdays"
      days_to_blackout = "0,6"
    elsif !deliverable_days["0"] && !deliverable_days["6"] && !deliverable_days["1"] && !deliverable_days["2"] && !deliverable_days["3"] && !deliverable_days["4"] && !deliverable_days["5"]
      availability_message = "Vendor currently does not deliver"
      days_to_blackout = "0,1,2,3,4,5,6"
    elsif deliverable_days["0"] && deliverable_days["6"] && deliverable_days["1"] && deliverable_days["2"] && deliverable_days["3"] && deliverable_days["4"] && deliverable_days["5"]
      availability_message = "Vendor delivers every day"
      days_to_blackout = ""
    else
      @account.delivery_on_sunday ? day_tracker.push('Sundays') : days_to_blackout += '0,'
      @account.delivery_on_monday ? day_tracker.push('Mondays') : days_to_blackout += '1,'
      @account.delivery_on_tuesday ? day_tracker.push('Tuesdays') : days_to_blackout += '2,'
      @account.delivery_on_wednesday ? day_tracker.push('Wednesdays') : days_to_blackout += '3,'
      @account.delivery_on_thursday ? day_tracker.push('Thursdays') : days_to_blackout += '4,'
      @account.delivery_on_friday ? day_tracker.push('Fridays') : days_to_blackout += '5,'
      @account.delivery_on_saturday ? day_tracker.push('Saturdays') : days_to_blackout += '6,'

      availability_message += day_tracker.to_sentence

    end

    [days_to_blackout, availability_message]
  end

  def load_date_options(options = {})
    order = options[:order]
    account = options[:account]
    account ||= order.try(:account)
    @days_available = generate_days(account)
    @next_available_day, @next_available_delivery_date = get_num_until_next_available_day(@days_available, options)
    @date_selected = order.try(:delivery_date).present?.to_s
  end
end
