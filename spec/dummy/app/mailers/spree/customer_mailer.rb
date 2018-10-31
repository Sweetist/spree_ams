module Spree
  class CustomerMailer < Spree::BaseMailer
    include AbstractController::Callbacks
    add_template_helper(DateHelper)
    before_filter :set_mail_type

    default from: "help@onsweet.co"

    def set_mail_type
      @mail_type = "vendor"
    end

  end
end
