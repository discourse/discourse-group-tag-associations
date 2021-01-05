# frozen_string_literal: true

# name: discourse-group-tag-associations
# about: Associate groups with tags and include tagged topics in group lists.
# version: 1.0
# authors: pmusaraj
# url: https://github.com/discourse/discourse-group-tag-associations

enabled_site_setting :group_tag_associations_enabled

PLUGIN_NAME ||= 'DiscourseGroupTagAssociations'

  %w[
    ../app/models/group_tag_association.rb
  ].each { |path| load File.expand_path(path, __FILE__) }

after_initialize do
  require_dependency File.expand_path('../app/controllers/groups_controller.rb', __FILE__)

  add_to_class(:group, :set_tag_associations) do
    GroupTagAssociation.batch_set(self, @associated_tags)
  end

  add_to_class(:group, "associated_tags=") do |tag_names|
    @associated_tags = tag_names
  end

  add_to_class(:group, :associated_tags) do
    GroupTagAssociation.where(group_id: id)
      .joins(:tag)
      .pluck(:name)
  end

  Group.class_eval do
    after_commit :set_tag_associations, on: [:create, :update]
    has_many :group_tag_associations, dependent: :destroy
    alias_method :discourse_posts_for, :posts_for

    def posts_for(guardian, opts = nil)
      if SiteSetting.group_tag_associations_enabled
        opts ||= {}
        result = Post.left_outer_joins(:topic, user: :groups, topic: [:category, { topic_tags: :tag }])
          .preload(:topic, user: :groups, topic: [:category, { topic_tags: :tag }])
          .references(:posts, :topics, :category, { topic_tags: :tag })
          .where('topics.visible')
          .where("(topics.archetype <> :pm AND groups.id = :id AND post_type IN (:type)) OR tags.name IN (:tags)",
            pm: Archetype.private_message, id: id, type: [Post.types[:regular], Post.types[:moderator_action]], tags: associated_tags)

        if opts[:category_id].present?
          result = result.where('topics.category_id = ?', opts[:category_id].to_i)
        end

        result = guardian.filter_allowed_categories(result)
        result = result.where('posts.id < ?', opts[:before_post_id].to_i) if opts[:before_post_id]
        result.order('posts.created_at desc')
      else
        discourse_posts_for(guardian, opts)
      end
    end
  end

  TopicQuery.class_eval do
    alias_method :discourse_list_group_topics, :list_group_topics

    def list_group_topics(group)
      if SiteSetting.group_tag_associations_enabled
        list = default_results.left_outer_joins(topic_tags: :tag).where("
          topics.user_id IN (
            SELECT user_id FROM group_users gu WHERE gu.group_id = #{group.id.to_i}
          )
          OR tags.name IN (?)", Group.find(group.id.to_i).associated_tags)

        create_list(:group_topics, {}, list)
      else
        discourse_list_group_topics(group)
      end
    end
  end

  add_to_serializer(:group_show, :associated_tags) do
    GroupTagAssociation.where(group_id: object.id)
      .joins(:tag)
      .pluck(:name)
  end
end
