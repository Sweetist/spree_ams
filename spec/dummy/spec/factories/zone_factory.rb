FactoryGirl.define do
  factory :global_zone, class: Spree::Zone do
    name 'GlobalZone'
    description { generate(:random_string) }
    vendor { |v| Spree::Company.first || v.association(:vendor) }
    zone_members do |proxy|
      zone = proxy.instance_eval { @instance }
      Spree::Country.all.map do |c|
        zone_member = Spree::ZoneMember.create(zoneable: c, zone: zone)
      end
    end
  end

  factory :zone, class: Spree::Zone do
    name { generate(:random_string) }
    description { generate(:random_string) }
    vendor { |v| Spree::Company.first || v.association(:vendor) }

    factory :zone_with_country do
      kind 'country'
      zone_members do |proxy|
        zone = proxy.instance_eval { @instance }
        country = Spree::Country.find_by_numcode(840) || create(:country)
        [Spree::ZoneMember.create(zoneable: country, zone: zone)]
      end
    end
  end
end
