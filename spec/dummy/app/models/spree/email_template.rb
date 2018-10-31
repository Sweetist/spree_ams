require 'liquid'
Liquid::Template.error_mode = :strict # Raises a SyntaxError when invalid syntax is used

module Spree
  class EmailTemplate < ActiveRecord::Base
    serialize :template, Liquid::Template

    validate :slug_needs_to_have_simple_format
    validates :slug,      presence: true
    validates :body,      presence: true
    validates :subject,   presence: true
    validates :template,  presence: true

    belongs_to :vendor, class_name: 'Spree::Company', foreign_key: :vendor_id, primary_key: :id

    before_validation :try_precompile

    def precompile
      begin
        self.template = Liquid::Template.parse( body )
      rescue Liquid::SyntaxError => error
        errors.add :template, error.message
      end
    end

    def mail_options
      {
        from: from,
        subject: subject,
        cc: cc,
        bcc: bcc
      }.delete_if { |_, v| v.blank? }
    end

    def render_preview(body, *args)
      if body.present?
        self.template = Liquid::Template.parse(body)
      end
      template.render( *args )
    end

    def render(*args)
      template.render( *args )
    end

    def restore_original_template
      file = File.new(Rails.root.to_s + self.file_path, 'r')

      self.attributes = File.open(file) do |f|
        attr = YAML.load(f)
        attr.is_a?(Hash) ? attr : {}
      end

      contents = file.read

      # match and store body of <mailer>.liquid file (after the section with the subject and to/from/bcc)
      match = contents.match(/(---+(.|\n)+---+)/)
      self.body = contents.gsub(match[1], '').strip if match
    end

  private

    def try_precompile
      precompile if body_changed?
    end

    def slug_needs_to_have_simple_format
      # convert slug to symbol
      # add error if symbol has non-simple format (i.e. `:"symbol with spaces"` vs `:symbol_with_underscores`)
      if /[@$"]/ =~ slug.to_sym.inspect || slug.match(/[A-Z]/)
        errors.add(:slug, 'must have a simple format with no spaces, capital letters, and most punctuation (good: "hello_world", bad: "hello, world")')
      end
    end
  end
end
