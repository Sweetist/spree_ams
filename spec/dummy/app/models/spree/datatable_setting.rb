module Spree
  class DatatableSetting < ActiveRecord::Base
    belongs_to :user

    validates :path_name, :user, :state, presence: true

    before_validation :set_default_state, on: :create

    def set_default_state
      self.state = state || default_state
    end

    def default_state
      { none: 'none' }
    end
  end
end
