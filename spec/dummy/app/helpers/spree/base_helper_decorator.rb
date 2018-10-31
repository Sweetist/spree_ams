Spree::BaseHelper.class_eval do
  def payment_method_name(payment)
    # hack to allow us to retrieve the name of a "deleted" payment method
    id = payment.payment_method_id
    name = Spree::PaymentMethod.find_with_destroyed(id).name
    I18n.t("payment_name.#{name}", default: name)
  end

  def pretty_time(time, zone = Sweet::Application.config.x.admin_time_zone)
    time = time.in_time_zone(zone)
    [I18n.l(time.to_date, format: :long), time.strftime("%l:%M %p %Z")].join(" ")
  end

  def available_countries
    countries = Spree::Country.order('name ASC')
    countries.collect do |country|
      country.name = Spree.t(country.iso, scope: 'country_names', default: country.name)
      country
    end
  end

  def overview_date_t
    DateHelper.company_date_to_UTC(overview_date, @vendor.date_format)
  end

  def overview_date
    params.fetch('overview-date', DateHelper.to_vendor_date_format(DateHelper.sweet_today(@vendor.time_zone), @vendor.date_format))
  end

  def preference_fields(object, form)
    return unless object.respond_to?(:preferences)
    fields = object.preferences.keys.map do |key|
      if object.has_preference?(key)
        form.label("preferred_#{key}", object.preference_label(key) + ': ') +
          preference_field_for(form, "preferred_#{key}", type: object.preference_type(key))
      end
    end
    safe_join(fields, '<br />'.html_safe)
  end

  private

    def define_image_method(style)
      self.class.send :define_method, "#{style}_image" do |product, *options|
        options = options.first || {}
        options[:alt] ||= product.name
        if product.images.empty?
          if !product.is_a?(Spree::Variant) && !product.variant_images.empty?
            image_tag "noimage/#{style}.png", options
          else
            if product.is_a?(Spree::Variant) && !product.product.variant_images.empty?
              if !product.product.images.empty?
                create_product_image_tag(product.product.images.first, product, options, style)
              else
                image_tag "noimage/#{style}.png", options
              end
            else
              image_tag "noimage/#{style}.png", options
            end
          end
        else
          create_product_image_tag(product.images.first, product, options, style)
        end
      end
    end

end
