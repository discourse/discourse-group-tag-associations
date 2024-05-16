# frozen_string_literal: true

module DiscourseGroupTagAssociations
  module GroupExtension
    extend ActiveSupport::Concern

    prepended do
      after_commit :set_tag_associations, on: %i[create update]
      has_many :group_tag_associations, dependent: :destroy
    end

    def posts_for(guardian, opts = nil)
      if SiteSetting.group_tag_associations_enabled && associated_tags.present?
        opts ||= {}

        tag_results =
          Post
            .joins(:topic, topic: { topic_tags: :tag })
            .preload(:topic, topic: { topic_tags: :tag })
            .references(:posts, :topics, { topic_tags: :tag })
            .where("topics.visible")
            .where("topics.archetype <> ?", Archetype.private_message)
            .where(post_type: [Post.types[:regular], Post.types[:moderator_action]])
            .where("tags.name IN (:tags)", tags: associated_tags)

        if opts[:category_id].present?
          tag_results = tag_results.where("topics.category_id = ?", opts[:category_id].to_i)
        end

        tag_results = guardian.filter_allowed_categories(tag_results)
        tag_results = tag_results.where("posts.id < ?", opts[:before_post_id].to_i) if opts[
          :before_post_id
        ]
        tag_results.order("posts.created_at desc")
      else
        super
      end
    end
  end
end
