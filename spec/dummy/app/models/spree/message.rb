module Spree
    class Message

        include ActiveModel::Model
        include ActiveModel::Conversion
        include ActiveModel::Validations

        attr_accessor :name, :email, :content, :company, :subject

        validates :name, :email, :content, :company, :subject, presence: true

    end
end