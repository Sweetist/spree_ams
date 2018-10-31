Commontator::SubscriptionsMailer.class_eval do
  def comment_created(comment, recipients, users_tagged)
    return if comment.try(:private?)
    setup_variables(comment, recipients, users_tagged)
    message = mail :to => @to,
                   :cc => @cc,
                   :from => @from,
                   :subject => t('commontator.email.comment_created.subject',
                                 :creator_name => @creator_name,
                                 :commontable_name => @commontable_name,
                                 :comment_url => @comment_url) unless @to.blank?

    message.mailgun_recipient_variables = mailgun_recipient_variables(recipients) if uses_mailgun?
  end

  protected

  def setup_variables(comment, recipients, users_tagged)
    @comment = comment
    @thread = @comment.thread
    @creator = @comment.creator

    @creator_name = Commontator.commontator_name(@creator)

    @commontable_name = Commontator.commontable_name(@thread)

    @comment_url = Commontator.comment_url(@comment, main_app)

    params = Hash.new
    params[:comment] = @comment
    params[:thread] = @thread
    params[:creator] = @creator
    params[:creator_name] = @creator_name
    params[:commontable_name] = @commontable_name
    params[:comment_url] = @comment_url
    if uses_mailgun?
      @to = recipient_emails(recipients)
    else
      @to = user_emails(users_tagged)
      @cc = recipient_emails(recipients)
      if @to.blank?
        @to = @cc
        @cc = []
      end
    end

    @from = @thread.config.email_from_proc.call(@thread)
  end

  def user_emails(users_tagged)
    users_tagged.collect{ |s| Commontator.commontator_email(s, self) }
  end
end
