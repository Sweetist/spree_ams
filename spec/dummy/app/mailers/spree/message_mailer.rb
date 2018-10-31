class Spree::MessageMailer < Spree::BaseMailer

  default from: "Customer <help@onsweet.co>"
  default to: "Help <help@onsweet.co>"

  def new_message(message)
    @message = message
    mail(from: @message.email, subject: @message.subject)
  end
end
