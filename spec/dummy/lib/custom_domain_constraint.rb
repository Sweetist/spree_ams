class CustomDomainConstraint
  def self.matches? request
    matching_blog?(request)
  end

  def self.matching_blog? request
    # Spree::Company.where(custom_domain: request.host).any? || Spree::Company.where(slug: request.host.split('.').first).any? || request.host == default_domain
    request.host == default_domain || Spree::Company.where(custom_domain: request.host).any?
  end

  def self.default_domain
    @default_domain ||= ENV['DEFAULT_URL_HOST']
  end
end
