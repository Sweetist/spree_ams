Spree::UserPasswordsController.class_eval do

  layout 'session'

  def create
   self.resource = resource_class.send_reset_password_instructions(params[resource_name])

    if resource.errors.empty?
      set_flash_message(:notice, :send_instructions) if is_navigational_format?
      flash[:success] = "Sent user reset instructions"
      respond_with resource, :location => spree.login_path
    else
      flash[:error] = "This user does not exist"
      respond_with_navigational(resource) { render :new }
      flash[:error] = nil
    end

  end
end
