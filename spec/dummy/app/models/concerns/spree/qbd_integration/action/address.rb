module Spree::QbdIntegration::Action::Address
  def qbd_address_to_address_xml(xml, addr_hash)
    return xml if addr_hash.blank?
    if addr_hash.is_a? Spree::Address
      addr_hash = addr_hash.to_integration(
        self.integration_item.integrationable_options_for(addr_hash)
      )
    end
    addr = []
    line = 0
    vendor_country_id = self.integration_item.vendor.try(:bill_address).try(:country_id)
    country_id = addr_hash.fetch(:country_id, nil)
    country_reqd = country_id.present? && country_id != vendor_country_id
    state = Spree::State.find_by_id(addr_hash.fetch(:state_id, nil)).try(:abbr)
    country = Spree::Country.find_by_id(addr_hash.fetch(:country_id, nil)).try(:name)

    if addr_hash.fetch(:company, nil).present?
      addr[line] = addr_hash.fetch(:company)
      line += 1
    end

    name = "#{addr_hash.fetch(:firstname, nil)} #{addr_hash.fetch(:lastname, nil)}".strip
    if name.present?
      addr[line] = name
      line += 1
    end

    addr2_included = false
    if addr_hash.fetch(:address1, nil).present?
      addr[line] = addr_hash.fetch(:address1)
      if country_reqd && addr_hash.fetch(:address2, nil).present? && line == 2 #if this is the third line
        addr[line] += ", #{addr_hash.fetch(:address2)}"
        addr2_included = true
        if addr[line].length > 41
          addr[line - 1] = addr_hash.fetch(:address1)
          addr[line] = addr_hash.fetch(:address2)
          new_first_line = "#{addr[line - 2]}, #{name}"
          addr[line - 2] = new_first_line if new_first_line.length <= 41
        end
      end

      line += 1
    end

    if addr_hash.fetch(:address2, nil).present? && !addr2_included
      addr[line] = addr_hash.fetch(:address2)
      line += 1
    end

    addr[0] = '' if addr[0].nil?
    addr[1] = '' if addr[1].nil?
    addr[2] = '' if addr[2].nil?
    addr[3] = '' if addr[3].nil? && !country_reqd

    addr.length.times do |i|
      case i + 1
      when 1
        xml.Addr1 addr[i]
      when 2
        xml.Addr2 addr[i]
      when 3
        xml.Addr3 addr[i]
      when 4
        xml.Addr4 addr[i]
      when 5
        xml.Addr5 addr[i]
      end
    end

    xml.City        addr_hash.fetch(:city, '').to_s
    xml.State       state.to_s
    xml.PostalCode  addr_hash.fetch(:zipcode, '').to_s
    if country_reqd
      xml.Country   country
    else
      xml.Country   ''
    end
  end
end
