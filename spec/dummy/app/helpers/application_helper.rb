module ApplicationHelper
  def sortable(column, title = nil)
    title ||= column.titleize
    css_class = (column == sort_column) ? "current #{sort_direction}" : nil
    direction = (column == sort_column && sort_direction == "asc") ? "desc" : "asc"
    link_to title, {:sort => column, :direction => direction}, {:class => css_class}
  end

  def current_controller?(names)
    names.any?{|name| name.downcase == controller_name.downcase}
  end

  def current_action?(name)
    params[:action].downcase == name.downcase
  end

  def current_vendor
    @current_vendor ||= Spree::Company.find_by_custom_domain(request.host)
    if @current_vendor.nil? && session[:spree_user_return_to].to_s.include?('shop')
      vendor_id = session[:spree_user_return_to].split('/')[2]
      @current_vendor ||= Spree::Company.friendly.find(vendor_id) rescue nil
    end

    @current_vendor
  end

  def current_vendor_logo
    current_vendor.try(:logo).try(:attachment).try(:url) || 'sweet.png'
  end

  def current_vendor_large_logo
    current_vendor.try(:logo).try(:attachment, :large) || 'sweet.png'
  end

  def overview_date
    params.fetch('overview-date', DateHelper.to_vendor_date_format(DateHelper.sweet_today(current_vendor.time_zone), current_vendor.date_format))
  end

  def next_day
    date = DateHelper.company_date_to_UTC(overview_date, current_vendor.date_format)
    DateHelper.to_vendor_date_format(date + 1.day, current_vendor.date_format)
  end

  def prev_day
    date = DateHelper.company_date_to_UTC(overview_date, current_vendor.date_format)
    DateHelper.to_vendor_date_format(date - 1.day, current_vendor.date_format)
  end

  # prints human-friednly boolean values
  def hb(boolean)
    boolean ? Spree.t(:say_yes) : Spree.t(:say_no)
  end

  # prints human-friednly permission level
  def pw(integer, opts = {})
    case integer
    when 0
      opts['0'] || "None"
    when 1
      opts['1'] || "Read"
    when 2
      opts['2'] || "Write"
    end
  end

  def overview_date_text
    date = DateHelper.company_date_to_UTC(overview_date, current_vendor.date_format)
    if (Time.current.beginning_of_day.to_datetime..Time.current.end_of_day.to_datetime).include?(date)
      "Today's"
    else
      overview_date
    end
  end

  def date_field_with_defaults(date_key, company, offset = 0.days)
    if params[date_key]
      params[date_key] = DateHelper.company_date_to_UTC(params[date_key], company.date_format)
    end

    params[date_key].present? ? params[date_key] : (Time.current - offset).in_time_zone(company.time_zone).to_date
  end

  def format_ransack_date_field(date_key, company)
    format_form_date_field(:q, date_key, company)
  end
  def format_ransack_datetime_field(datetime_key, company)
    format_form_datetime_field(:q, datetime_key, company)
  end

  def format_form_datetime_field(base_key, datetime_key, company)
    if base_key.present? && params[base_key] && params[base_key][datetime_key].present?
      params[base_key][datetime_key] = gt_or_lt_date_time(datetime_key, params[base_key][datetime_key], company)
    else
      params[datetime_key] = gt_or_lt_date_time(datetime_key, params[datetime_key], company)
    end
  end

  def gt_or_lt_date_time(datetime_key, date_str, company)
    zone = company.try(:time_zone) || 'UTC'
    tz_offset = ActiveSupport::TimeZone.new(zone).now.utc_offset

    if datetime_key.to_s.include?('_gt')
      DateHelper.company_date_to_UTC(date_str, company.date_format).beginning_of_day - tz_offset
    elsif datetime_key.to_s.include?('_lt')
      DateHelper.company_date_to_UTC(date_str, company.date_format).end_of_day - tz_offset
    else
      DateHelper.company_date_to_UTC(date_str, company.date_format) - tz_offset
    end
  rescue
    ''
  end

  def format_form_date_field(base_key, date_key, company)
    if base_key.present? && params[base_key] && params[base_key][date_key].present?
      params[base_key][date_key] = DateHelper.company_date_to_UTC(params[base_key][date_key], company.date_format)
    else
      params[date_key] = DateHelper.company_date_to_UTC(params[date_key], company.date_format)
    end
  end

  def revert_ransack_date_to_view(date_key, company)
    revert_date_to_view_format(:q, date_key, company)
  end
  def revert_ransack_datetime_to_view(datetime_key, company)
    revert_datetime_to_view_format(:q, datetime_key, company)
  end

  def revert_datetime_to_view_format(base_key, datetime_key, company)
    zone = company.try(:time_zone) || 'UTC'
    tz_offset = ActiveSupport::TimeZone.new(zone).now.utc_offset

    if base_key.present? && params[base_key] && params[base_key][datetime_key].present?
      params[base_key][datetime_key] = DateHelper.display_vendor_date_format(
        params[base_key][datetime_key] + tz_offset,
        company.date_format
      )
    elsif params[datetime_key].present?
      params[datetime_key] = DateHelper.display_vendor_date_format(
        params[datetime_key] + tz_offset,
        company.date_format
      )
    end
  end

  def revert_date_to_view_format(base_key, date_key, company)
    if base_key.present? && params[base_key] && params[base_key][date_key].present?
      params[base_key][date_key] = DateHelper.display_vendor_date_format(params[base_key][date_key], company.date_format)
    elsif params[date_key].present?
      params[date_key] = DateHelper.display_vendor_date_format(params[date_key], company.date_format)
    end
  end

  def text_align_opts
    [['Left', 'left'], ['Center', 'center'], ['Right', 'right'], ['Justify', 'justify']]
  end

  def display_on_opts
    [['My Company', 'back_end'],['Customers', 'front_end'],['Both', 'both']]
  end

  def show_invite_button?(contact)
    contact.can_invite?
  end

  def darken_color(hex_color, amount = 1, min = 0.5)
    hex_color = hex_color.gsub('#','')
    amount = [amount, min].max
    rgb = hex_color.scan(/../).map {|color| color.hex}
    rgb[0] = (rgb[0].to_i * amount).round
    rgb[1] = (rgb[1].to_i * amount).round
    rgb[2] = (rgb[2].to_i * amount).round
    "#%02x%02x%02x" % rgb
  end

end
