Spree::UserSessionsController.class_eval do

  layout 'session'
  def after_sign_in_path_for(resource)
    # host_arr = request.host.split('.')
    # host_company = Spree::Company.where(custom_domain: request.host).first || Spree::Company.where(slug: request.host.split('.')).first
    # if host_arr[0] == 'app' || host_arr[0] == "localhost" || host_arr[0] == "dev" || host_arr[0] == "staging" || resource.is_customer? || resource.is_vendor? || host_company == resource.company
      if request.referer == login_url
        super
      else
        if resource.is_admin?
          path = admin_path
        elsif resource.is_vendor?
          path = manage_path
        elsif resource.is_customer?
          path = vendors_path
        else
          flash[:errors] = "You have not been given permission to use this site."
          path = '/'
        end

        stored_location_for(resource) || request.referer || path
      end
    # elsif spree_current_user.is_admin?
    #   flash[:error] = "You have not been given permission to use this site."
    #   admin_path
    # else
    #   #vendor goes throug here but customer does not
    #   sign_out(resource)
    #   flash[:error] = "You have not been given permission to use this site."
    #   '/login'
    # end
  end

  def request_access
    render :request_access
  end

end
