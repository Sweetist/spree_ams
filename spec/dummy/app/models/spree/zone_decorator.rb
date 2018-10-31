Spree::Zone.class_eval do
  clear_validators!
  has_many :cities, through: :zone_members, source: :zoneable, source_type: "Spree::City"
  belongs_to :vendor, class_name: 'Spree::Company', foreign_key: :vendor_id, primary_key: :id
  validates :vendor_id, presence: true
  validates :name, presence: true, uniqueness: { scope: :vendor_id }

  attr_accessor :filter_id

  def self.default_tax(vendor_id = nil)
    where(default_tax: true, vendor_id: vendor_id).first
  end

  def self.match(address, vendor_id)
    address_city_id = find_city(address).try(:id)
    return unless address &&
      matches = includes(:zone_members).
        order('spree_zones.zone_members_count', 'spree_zones.created_at').
        where(
          "spree_zones.vendor_id = ? AND
          ((spree_zone_members.zoneable_type = 'Spree::Country' AND
            spree_zone_members.zoneable_id = ?) OR
            (spree_zone_members.zoneable_type = 'Spree::State' AND
            spree_zone_members.zoneable_id = ?) OR
            (spree_zone_members.zoneable_type = 'Spree::City' AND
            spree_zone_members.zoneable_id = ?
          ))",
          vendor_id, address.country_id, address.state_id, address_city_id
        ).references(:zones).distinct
    ['city','state', 'country'].each do |zone_kind|
      if match = matches.detect do |zone|
        zone_kind == zone.kind
      end
        return match
      end
    end
    matches.first
  end

  def include?(address)
    return false unless address
    # NOTE: This is complicated by the fact that include? for HMP is broken in Rails 2.1 (so we use awkward index method)
    members.any? do |zone_member|
      case zone_member.zoneable_type
      when "Spree::Zone"
        zone_member.zoneable.include?(address)
      when "Spree::Country"
        zone_member.zoneable_id == address.country_id
      when "Spree::City"
        result = false
        address_city = Spree::Zone.find_city(address)

        if address_city.present?
          result = (zone_member.zoneable_id == address_city.id)
        end

        result
      when "Spree::State"
        zone_member.zoneable_id == address.state_id
      else
        false
      end
    end
  end

  def kind
    if kind?
      super
    else
      not_nil_scope = members.where.not(zoneable_type: nil)
      zone_type = not_nil_scope.order('created_at ASC').pluck(:zoneable_type).last
      zone_type.demodulize.underscore if zone_type
    end
  end

  def city?
    kind == 'city'
  end

  def country_list
    members.map {|zone_member|
      case zone_member.zoneable_type
      when "Spree::Zone"
        zone_member.zoneable.country_list
      when "Spree::Country"
        zone_member.zoneable
      when "Spree::State"
        zone_member.zoneable.country
      when "Spree::City"
        zone_member.zoneable.country_list
      else
        nil
      end
    }.flatten.compact.uniq
  end

  def self.find_city(address)
    address_city = nil
    if address.try(:city).present? && address.try(:state).present?
      address_city = Spree::City.where('name ILIKE ? AND state_id = ?', address.city, address.state_id).first
    end
    address_city
  end

  def city_ids
    if kind == 'city'
      members.pluck(:zoneable_id)
    else
      []
    end
  end

  def city_ids=(ids)
    set_zone_members(ids, 'Spree::City')
  end

  def self.potential_matching_zones(zone, vendor_id = nil)
    if zone.country?
      # Match zones of the same kind with similar countries
      joins(countries: :zones).
        where('spree_zones.vendor_id = ? AND ' +
          '(zone_members_spree_countries_join.zone_id = ? OR ' +
          'spree_zones.default_tax = ?)',
          vendor_id, zone.id, true).uniq
    elsif zone.city?
      joins(:zone_members).where(
        "spree_zones.vendor_id = ? AND ((spree_zone_members.zoneable_type = 'Spree::City' AND
          spree_zone_members.zoneable_id IN (?))
          OR (spree_zone_members.zoneable_type = 'Spree::State' AND
          spree_zone_members.zoneable_id IN (?))
          OR (spree_zone_members.zoneable_type = 'Spree::Country' AND
          spree_zone_members.zoneable_id IN (?))
          OR default_tax = ?)",
        vendor_id,
        zone.city_ids,
        zone.cities.pluck(:state_id),
        zone.states.pluck(:country_id),
        true
      ).uniq
    else
      # Match zones of the same kind with similar states in AND match zones
      # that have the states countries in
      joins(:zone_members).where(
        "spree_zones.vendor_id = ? AND
         ((spree_zone_members.zoneable_type = 'Spree::State' AND
           spree_zone_members.zoneable_id IN (?))
          OR (spree_zone_members.zoneable_type = 'Spree::Country' AND
           spree_zone_members.zoneable_id IN (?))
          OR default_tax = ?)",
        vendor_id,
        zone.state_ids,
        zone.states.pluck(:country_id),
        true
      ).uniq
    end
  end

  private

  def remove_previous_default
    if self.default_tax?
      Spree::Zone.where(vendor_id: self.vendor_id)
        .where.not(id: self.id)
        .update_all(default_tax: false)
    end
  end
end
