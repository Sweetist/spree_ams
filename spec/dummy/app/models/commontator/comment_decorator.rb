Commontator::Comment.class_eval do
  # It is OK to change the names of the strings in this constant, but the
  # order must remain the same! So 'internal' could be company or 'private'
  # could be personal.
  # 'internal': shared only with other people within your organization based on
  # having the same spree_role
  # 'public': shared with everyone
  # 'private': only the author of the comment can see it
  SHARE_LEVELS=['internal', 'public', 'private'].freeze unless const_defined?(:SHARE_LEVELS)
  validates :share_level, presence: true

  def private?
    share_level == 'private'
  end

  def internal?
    share_level == 'internal'
  end

  def public?
    share_level == 'public'
  end

  def can_be_read_by?(user)
    return true if share_level == 'public'
    return true if share_level == 'private' && creator_id == user.id
    return true if share_level == 'internal' && creator.try(:company_id) == user.company_id

    false
  end

end
