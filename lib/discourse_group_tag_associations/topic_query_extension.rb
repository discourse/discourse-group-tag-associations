# frozen_string_literal: true

module DiscourseGroupTagAssociations
  module TopicQueryExtension
    extend ActiveSupport::Concern

    def list_group_topics(group)
      associated_tags = Group.find(group.id.to_i).associated_tags

      if SiteSetting.group_tag_associations_enabled && associated_tags.present?
        list = default_results.joins(topic_tags: :tag).where("tags.name IN (?)", associated_tags)
        create_list(:group_topics, {}, list)
      else
        super
      end
    end
  end
end
