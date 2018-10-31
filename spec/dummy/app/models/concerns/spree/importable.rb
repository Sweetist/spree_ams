module Spree::Importable
  extend ActiveSupport::Concern

  def status_message
    case status
      when 0
        "Queued"
      when 1
        "Verifying"
      when 2
        "Verified"
      when 3
        "Errors"
      when 4
        "Queued"
      when 5
        "Importing"
      when 6
        "Imported"
      when 10
        "Failed"
    end
  end

  def find_time_zone(tz_abbr, country = 'United States')
    tz_abbr = tz_abbr.to_s.upcase
    zones = {
      'United States' => {
        'AST' => "Atlantic Time (Canada)",
        'AKST' => "Alaska",
        'AKDT' => "Alaska",
        'EST' => "Eastern Time (US & Canada)",
        'EDT' => "Eastern Time (US & Canada)",
        'CST' => "Central Time (US & Canada)",
        'CDT' => "Central Time (US & Canada)",
        'MST' =>  "Mountain Time (US & Canada)",
        'MDT' =>  "Mountain Time (US & Canada)",
        'PST' =>  "Pacific Time (US & Canada)",
        'PDT' =>  "Pacific Time (US & Canada)",
        'HST' =>  "Hawaii",
        'HAST'=>  "Hawaii",
        'HADT'=>  "Hawaii"
      },
      'Canada' =>{
        'NST' =>  "Newfoundland",
        'NDT' =>  "Newfoundland",
        'AST' =>  "Atlantic Time (Canada)",
        'ADT' =>  "Atlantic Time (Canada)",
        'EST' =>  "Eastern Time (US & Canada)",
        'EDT' =>  "Eastern Time (US & Canada)",
        'CST' =>  "Central Time (US & Canada)",
        'CDT' =>  "Central Time (US & Canada)",
        'MST' =>  "Mountain Time (US & Canada)",
        'MDT' =>  "Mountain Time (US & Canada)",
        'PST' =>  "Pacific Time (US & Canada)",
        'PDT' =>  "Pacific Time (US & Canada)",
        'YST' =>  "Pacific Time (US & Canada)",
        'YDT' =>  "Pacific Time (US & Canada)"
      }
    }
    ActiveSupport::TimeZone[zones.fetch(country, {}).fetch(tz_abbr, '')]
  end

end
