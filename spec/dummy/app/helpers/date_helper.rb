module DateHelper
  SS_DATE_FORMAT = "%m/%d/%Y %H:%M %Z"
  def sweet_date(time, zone = Sweet::Application.config.x.admin_time_zone, length = :long)
    time.in_time_zone(zone).to_date.to_formatted_s(length) rescue ""
  end

  def sweet_time(time, zone = Sweet::Application.config.x.admin_time_zone, length = :long)
    time.in_time_zone(zone).to_formatted_s(length) rescue ""
  end

  def sweet_full_date_time(datetime, zone = Sweet::Application.config.x.admin_time_zone)
    datetime.in_time_zone(zone).strftime("%-d %^b %Y, %l:%M %p %Z") rescue ''
    # example: 5 MAR 2016, 2:58 PM EST
  end

  def self.sweet_full_date_time(datetime, zone = Sweet::Application.config.x.admin_time_zone)
    datetime.in_time_zone(zone).strftime("%-d %^b %Y, %l:%M %p %Z") rescue ''
    # example: 5 MAR 2016, 2:58 PM EST
  end
  # to use it in controller
  def self.sweet_date(time, zone = Sweet::Application.config.x.admin_time_zone, length = :long)
    time.in_time_zone(zone).to_date.to_formatted_s(length) rescue ""
  end

  def self.sweet_time(time, zone = Sweet::Application.config.x.admin_time_zone, length = :long)
    time.in_time_zone(zone).to_formatted_s(length) rescue ""
  end

  def self.ss_time_to_db(date)
    Time.strptime(date + " UTC", SS_DATE_FORMAT)
  end


  def self.sweet_today(zone = 'UTC')
    Time.current.in_time_zone(zone).to_date
  end

  def self.sweet_tomorrow(zone = 'UTC')
    Time.current.in_time_zone(zone).to_date + 1.day
  end

  # to use in views for displaying in datepickers
  def display_vendor_date_format(date, date_format = 'mm/dd/yyyy')
    case date_format
    when 'mm/dd/yyyy'
      date.strftime('%m/%d/%Y') rescue ''
    when 'dd/mm/yyyy'
      date.strftime('%d/%m/%Y') rescue ''
    end
  end

  def display_vendor_date_time_format(datetime, date_format = 'mm/dd/yyyy', zone = 'UTC')
    return '' unless datetime
    dt = datetime.in_time_zone(zone)
    case date_format
    when 'mm/dd/yyyy'
      dt.strftime('%m/%d/%Y %l:%M %p %Z') rescue ''
    when 'dd/mm/yyyy'
      dt.strftime('%d/%m/%Y %l:%M %p %Z') rescue ''
    end
  end

  def today_in_vendor_date_format(zone = 'UTC', date_format = 'mm/dd/yyyy')
    today = DateHelper.sweet_today(zone)
    DateHelper.display_vendor_date_format(today, date_format)
  end

  def self.display_vendor_date_format(date, date_format = 'mm/dd/yyyy')
    case date_format
    when 'mm/dd/yyyy'
      date.strftime('%m/%d/%Y') rescue ''
    when 'dd/mm/yyyy'
      date.strftime('%d/%m/%Y') rescue ''
    end
  end

  def self.display_vendor_date_time_format(datetime, date_format = 'mm/dd/yyyy', zone = 'UTC')
    return '' unless datetime
    dt = datetime.in_time_zone(zone)
    case date_format
    when 'mm/dd/yyyy'
      dt.strftime('%m/%d/%Y %l:%M %p %Z') rescue ''
    when 'dd/mm/yyyy'
      dt.strftime('%d/%m/%Y %l:%M %p %Z') rescue ''
    end
  end

  def self.to_vendor_date_format(datetime, date_format = 'mm/dd/yyyy')
    case date_format
    when 'mm/dd/yyyy'
      datetime.strftime('%m/%d/%Y') rescue ''
    when 'dd/mm/yyyy'
      datetime.strftime('%d/%m/%Y') rescue ''
    end
  end

  def self.to_db_from_frontend(date, vendor)
    case vendor.date_format
    when 'mm/dd/yyyy'
      Date.strptime(date, '%m/%d/%Y')
          .in_time_zone(vendor.time_zone)
          .in_time_zone('UTC')
    when 'dd/mm/yyyy'
      Date.strptime(date, '%d/%m/%Y')
          .in_time_zone(vendor.time_zone)
          .in_time_zone('UTC')
    end
  rescue
    ''
  end

  # to use in controllers for accepting inputs in datepickers
  def self.company_date_to_UTC(date, date_format = 'mm/dd/yyyy')
    case date_format
    when 'mm/dd/yyyy'
      Date.strptime(date, '%m/%d/%Y').in_time_zone('UTC') rescue ''
    when 'dd/mm/yyyy'
      Date.strptime(date, '%d/%m/%Y').in_time_zone('UTC') rescue ''
    end
  end
end
