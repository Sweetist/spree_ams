module Integrations
  module Address
    def state_object
      return unless state.present?
      c = country_object
      if c.present?
        s = c.states.find_by(abbr: state)
        s ||= c.states.find_by(name: state)
      else
        s = Spree::State.find_by(abbr: state)
        s ||= Spree::State.find_by(name: state)
      end

      s
    end

    def country_object
      return unless country.present?
      c = Spree::Country.find_by(iso: country)
      c ||= Spree::Country.find_by(iso3: country)
      c ||= Spree::Country.find_by(name: country)

      c
    end

    def spree_object
      address = Spree::Address
                .find_or_create_by!(address1: @data.dig('address1'),
                                    address2: @data.dig('address2'),
                                    zipcode: @data.dig('zipcode'),
                                    city: @data.dig('city'),
                                    state: state_object,
                                    country: country_object,
                                    addr_type: addr_type)
      address.update(phone: @data.dig('phone'))
      address
    end
  end
end
