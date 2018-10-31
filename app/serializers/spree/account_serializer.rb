module Spree
  class AccountSerializer < ActiveModel::Serializer
    attributes :id, :fully_qualified_name, :email
  end
end
