Spree::Address.class_eval do
  include Spree::Integrationable

  clear_validators!
  include Spree::Integrationable
  has_paper_trail class_name: 'Spree::Version'
  validate :state_validate, :postal_code_validate
  belongs_to :account, class_name: "Spree::Account", foreign_key: :account_id, primary_key: :id

  def self.display_addr_text(addr, company_default = nil)
    return "" if addr.nil?
    # writing as class method to be usable by stock locations as well as address objects
    csz = "#{addr.city}"
    state = "#{addr.state.try(:abbr)}"
    csz += ", " unless csz.blank? || state.blank?
    csz += state
    csz += " #{addr.zipcode}"
    csz = csz.strip

    [
      "#{addr.try(:company).blank? ? company_default : addr.company }",
      "#{addr.try(:address1)}",
      "#{addr.try(:address2)}",
      "#{csz}",
      "#{addr.try(:country).try(:name)}"
    ].reject { |line| line.blank? }.join("\n")
  end

  def display_addr_text
    Spree::Address.display_addr_text(self)
  end

  def one_line_summary(html=true)
    return "" if self.nil?

    name = "#{self.firstname} #{self.lastname}".strip
    street_address = "#{self.address1} #{self.address2}".strip

    csz = "#{self.city}"
    state = "#{self.state.try(:abbr)}"
    csz += ", " unless csz.blank? || state.blank?
    csz += state
    csz += " #{self.zipcode}" if self.zipcode
    csz = csz.strip

    country = self.try(:country).try(:name)

    if name.present?
      summary = "<strong>#{name}</strong> #{street_address}, #{csz} #{self.try(:country).try(:name)}".strip
    else
      summary = "#{street_address}, #{csz} #{self.try(:country).try(:name)}".strip
    end

    if html
      return summary
    else
      return ActionView::Base.full_sanitizer.sanitize(summary)
    end
  end

  def require_phone?
    false
  end

  def require_zipcode?
    false
  end

  def self.attributes_to_ignore_when_comparing
    %w[id created_at updated_at addr_type]
  end

  def same_address?(other)
    return false unless other.is_a?(self.class)
    self.attributes.except(*self.class.attributes_to_ignore_when_comparing) ==
    other.attributes.except(*self.class.attributes_to_ignore_when_comparing)
  end

  private

  def state_validate
        # Skip state validation without country (also required)
        # or when disabled by preference
        return if country.blank? || !Spree::Config[:address_requires_state]
        return unless country.states_required

        # ensure associated state belongs to country
        if state.present?
          if state.country == country
            self.state_name = nil #not required as we have a valid state and country combo
          else
            if state_name.present?
              self.state = nil
            else
              errors.add(:state, :invalid)
            end
          end
        end

        # ensure state_name belongs to country without states, or that it matches a predefined state name/abbr
        if state_name.present?
          if country.states.present?
            states = country.states.find_all_by_name_or_abbr(state_name)

            if states.size == 1
              self.state = states.first
              self.state_name = nil
            else
              errors.add(:state, :invalid)
            end
          end
        end

        # ensure at least one state field is populated
        # errors.add :state, :blank if state.blank? && state_name.blank?
      end

      def postal_code_validate
        return if zipcode.blank? || country.blank? || country.iso.blank?
        return if !TwitterCldr::Shared::PostalCodes.territories.include?(country.iso.downcase.to_sym)

        postal_code = TwitterCldr::Shared::PostalCodes.for_territory(country.iso)
        errors.add(:zipcode, :invalid) if !postal_code.valid?(zipcode.to_s.strip)
      end

end
