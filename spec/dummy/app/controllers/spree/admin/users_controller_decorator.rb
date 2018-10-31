Spree::Admin::UsersController.class_eval do
  after_action :give_customer_account_access, only: [:create, :update]

  private

  def give_customer_account_access
    if @user.try(:has_spree_role?, 'customer')
      @user.company.vendor_accounts.each do |account|
        account.user_accounts.find_or_create_by(user_id: @user.id)
      end
    end
    if @user && @user.company
      @user.user_accounts.where.not(account_id: @user.company.vendor_account_ids).destroy_all
    end
  end
end
