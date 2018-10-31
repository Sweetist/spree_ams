Commontator::Subscription.class_eval do
    def self.comment_created(comment, users_tagged)
      recipients = comment.thread.subscribers.reject{|s| (s == comment.creator) || (users_tagged.include?(s))}
      mail = Commontator::SubscriptionsMailer.comment_created(comment, recipients, users_tagged)
      mail.deliver
    end
  end
