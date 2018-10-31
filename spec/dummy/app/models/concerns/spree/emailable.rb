module Spree::Emailable
  def emails(base = nil)
    if base.present?
      obj_emails = self.send("#{base}_email")
    else
      obj_emails = self.email
    end

    return [] unless obj_emails.present?
    obj_emails.split(',').map(&:strip)
  end

  def has_all_valid_emails?(base = nil)
    self.emails(base).all? do |addr|
      match = /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i.match(addr)
      !match.nil?
    end
  end

  def has_all_valid_or_blank_emails?(base = nil)
    emails(base).blank? || has_all_valid_emails?(base)
  end

  def ensure_all_valid_or_blank_emails(base = nil)
    if has_all_valid_or_blank_emails?(base)
      true
    else
      if base.present? && self.send("#{base}_email").include?(',')
        self.errors.add("#{base}_email", "at least one #{base} email has an invalid format")
      elsif base.present?
        self.errors.add("#{base}_email", 'format is invalid')
      elsif self.email.include?(',')
        self.errors.add(:email, 'at least one email has an invalid format')
      else
        self.errors.add(:email, 'format is invalid')
      end
      false
    end
  end

  def has_any_valid_emails(base = nil)
    self.emails(base).any? do |addr|
      match = /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i.match(addr)
      !match.nil?
    end
  end

  def valid_emails(base = nil)
    self.emails(base).select do |addr|
      match = /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i.match(addr)
      addr if !match.nil?
    end
  end

  def valid_emails_string(base = nil)
    self.valid_emails(base).join(', ')
  end

  def has_valid_email?(base = nil)
    valid_emails(base).present?
  end
end
