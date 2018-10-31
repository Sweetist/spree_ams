
Commontator::CommentsController.class_eval do


  # POST /threads/1/comments
  def create
    @comment = Commontator::Comment.new
    @comment.thread = @thread
    @comment.creator = @user
    @comment.body = params[:comment].nil? ? nil : params[:comment][:body]
    @comment.share_level = params[:comment].nil? ? nil : params[:comment][:share_level]
    security_transgression_unless @comment.can_be_created_by?(@user)
    subscribe_mentioned if Commontator.mentions_enabled
    users_tagged = Commontator.commontator_mentions(@user, '').where(id: params[:mentioned_ids]);
    respond_to do |format|
      if  !params[:cancel].nil?
        format.html { redirect_to @thread }
        format.js { render :cancel }
      elsif @comment.save
        sub = @thread.config.thread_subscription.to_sym
        @thread.subscribe(@user) if sub == :a || sub == :b
        Commontator::Subscription.comment_created(@comment, users_tagged)

        @per_page = params[:per_page] || @thread.config.comments_per_page

        format.html { redirect_to @thread }
        format.js
      else
        format.html { redirect_to @thread }
        format.js { render :new }
      end
    end
  end

  def update
    security_transgression_unless @comment.can_be_edited_by?(@user)
    @comment.body = params[:comment].nil? ? nil : params[:comment][:body]
    @comment.share_level = params[:comment].nil? ? nil : params[:comment][:share_level]
    @comment.editor = @user
    subscribe_mentioned if Commontator.mentions_enabled

    respond_to do |format|
      if !params[:cancel].nil?
        format.html { redirect_to @thread }
        format.js { render :cancel }
      elsif @comment.save
        format.html { redirect_to @thread }
        format.js
      else
        format.html { redirect_to @thread }
        format.js { render :edit }
      end
    end
  end
end
