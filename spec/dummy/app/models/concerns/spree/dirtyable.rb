module Spree::Dirtyable
  extend ActiveSupport::Concern

  WhatChanged = Struct.new(:object, :changes) do
    def changed?
      self != NoChanges
    end
    delegate :has_key?, to: :changes
  end
  NoChanges = WhatChanged.new(nil, nil)

  def what_changed?
    what_changed = nil

    self.previous_changes.delete('updated_at')
    unless self.previous_changes.empty?
      what_changed = WhatChanged.new(self, self.previous_changes)
    end

    associations = self.try(:dirtyable_associations) || []
    associations.each do |association_name|
      catch :next_association_name do
        association_collection = self.send(association_name)
        throw :next_association_name unless association_collection
        throw :next_association_name if association_collection.empty?

        association_collection.each do |item|
          throw :next_association_name unless item.respond_to?(:what_changed?)

          association_changes = item.what_changed?
          if association_changes != NoChanges
            what_changed ||= WhatChanged.new(self, {})

            what_changed.changes[association_name] ||= []
            what_changed.changes[association_name] << association_changes
          end
        end
      end
    end

    what_changed || NoChanges
  end
end
