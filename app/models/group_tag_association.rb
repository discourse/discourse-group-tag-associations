# frozen_string_literal: true

class GroupTagAssociation < ActiveRecord::Base
  belongs_to :group
  belongs_to :tag

  def self.batch_set(group, tag_names)
    tag_names ||= []
    self.where(group: group).destroy_all

    if tag_names.length > 0
      tag_ids = Set.new(Tag.where_name(tag_names).pluck(:id))
      tag_ids.each { |id| self.create!(group: group, tag_id: id) }
    end
  end
end

# == Schema Information
#
# Table name: group_tag_associations
#
#  id       :bigint           not null, primary key
#  group_id :integer          not null
#  tag_id   :integer          not null
#
# Indexes
#
#  idx_group_tag_associations_unique  (group_id,tag_id) UNIQUE
#
