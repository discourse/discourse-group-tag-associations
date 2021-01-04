# frozen_string_literal: true

class GroupTagAssociation < ActiveRecord::Base
  belongs_to :group
  belongs_to :tag

  def self.batch_set(group, tag_names)
    tag_names ||= []
    changed = false

    records = self.where(group: group)
    old_ids = records.pluck(:tag_id)

    tag_ids = tag_names.empty? ? [] : Tag.where_name(tag_names).pluck(:id)

    Tag.where_name(tag_names).joins(:target_tag).each do |tag|
      tag_ids[tag_ids.index(tag.id)] = tag.target_tag_id
    end

    tag_ids.uniq!

    remove = (old_ids - tag_ids)
    if remove.present?
      records.where('tag_id in (?)', remove).destroy_all
      changed = true
    end

    (tag_ids - old_ids).each do |id|
      self.create!(group: group, tag_id: id)
      changed = true
    end

    changed
  end
end

# == Schema Information
#
# Table name: group_tag_associations
#
#  id                 :bigint           not null, primary key
#  group_id           :integer          not null
#  tag_id             :integer          not null
#
# Indexes
#
#  idx_group_tag_associations_unique  (group_id,tag_id) UNIQUE
#
