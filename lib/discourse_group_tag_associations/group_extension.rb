# frozen_string_literal: true

module DiscourseGroupTagAssociations
  module GroupExtension
    extend ActiveSupport::Concern

    prepended do
      after_commit :set_tag_associations, on: %i[create update]
      has_many :group_tag_associations, dependent: :destroy
    end

    def posts_for(guardian, opts = nil)
      associated_tag_names = associated_tags(guardian) if SiteSetting.group_tag_associations_enabled

      if associated_tag_names.present?
        opts ||= {}

        tag_results =
          Post
            .joins(:topic, topic: { topic_tags: :tag })
            .preload(:topic, topic: { topic_tags: :tag })
            .references(:posts, :topics, { topic_tags: :tag })
            .where("topics.visible")
            .where("topics.archetype <> ?", Archetype.private_message)
            .where(post_type: [Post.types[:regular], Post.types[:moderator_action]])
            .where("tags.name IN (:tags)", tags: associated_tag_names)

        filter_posts_for_guardian(tag_results, guardian, opts)
      else
        super
      end
    end
  end
end
