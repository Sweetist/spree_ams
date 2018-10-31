require 'active_model_serializers'

module Spree
  module Wombat
    class AccountSerializer < ActiveModel::Serializer
      attributes :fully_qualified_name, :email
    end
  end
end
