module Spree
  module Cust
    class MessagesController < Spree::Cust::CustomerHomeController

      def index
        redirect_to :new
      end

      def new
        @message = Spree::Message.new
      end

      def create
        @message = Spree::Message.new(message_params)

        if @message.valid?
          Spree::MessageMailer.new_message(@message).deliver_now
          flash[:notice] = "Thank you for your message."
          redirect_to new_message_path
        else
          flash.now[:alert] = @message.errors.full_messages
          render :new
        end
      end

      private

      def message_params
        params.require(:message).permit(:name, :email, :content, :company, :subject)
      end

    end
  end
end
