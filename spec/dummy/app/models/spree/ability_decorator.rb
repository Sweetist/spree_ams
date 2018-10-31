Spree::Ability.class_eval do
  def initialize(user)
    self.clear_aliased_actions

    # override cancan default aliasing (we don't want to differentiate between read and index)
    alias_action :delete, to: :destroy
    alias_action :edit, to: :update
    alias_action :new, to: :create
    alias_action :new_action, to: :create
    alias_action :show, to: :read
    alias_action :index, :read, to: :display
    alias_action :create, :update, :destroy, to: :modify

    user ||= Spree.user_class.new

    # TODO give access to vendor user to api, but not to the rest of admin
    if user.respond_to?(:has_spree_role?) && user.has_spree_role?('admin') #|| user.is_vendor?
      can :manage, :all
    else
      can :display, Spree::Country
      can :display, Spree::OptionType
      can :display, Spree::OptionValue
      can :create, Spree::Order
      can [:read, :update], Spree::Order do |order, token|
        order.user == user || order.guest_token && token == order.guest_token
      end
      can :display, Spree::CreditCard, user_id: user.id
      can :display, Spree::Product
      can :display, Spree::ProductProperty
      can :display, Spree::Property
      can :create, Spree.user_class
      can [:read, :update, :destroy], Spree.user_class, id: user.id
      can :display, Spree::State
      can :display, Spree::Taxon
      can :display, Spree::Taxonomy
      can :display, Spree::Variant
      can :display, Spree::Zone
    end

    # Include any abilities registered by extensions, etc.
    Spree::Ability.abilities.merge(abilities_to_register).each do |clazz|
      ability = clazz.send(:new, user)
      @rules = rules + ability.send(:rules)
    end

    # Protect admin role
    cannot [:update, :destroy], Spree::Role, name: ['admin']
  end

  private

  # you can override this method to register your abilities
  # this method has to return array of classes
  def abilities_to_register
    []
  end

end
