# frozen_string_literal: true

# name: discourse-group-tag-associations
# about: Associate groups with tags and include tagged topics in group lists.
# version: 1.0
# authors: pmusaraj
# url: https://github.com/discourse/discourse-group-tag-associations

enabled_site_setting :group_tag_associations_enabled

after_initialize do
  module ::DiscourseGroupTagAssociations
    PLUGIN_NAME = "discourse-group-tag-associations"
  end

  require_relative "app/models/group_tag_association"
  require_relative "lib/discourse_group_tag_associations/group_extension"
  require_relative "lib/discourse_group_tag_associations/topic_query_extension"
  require_relative "lib/discourse_group_tag_associations/groups_controller_extension"

  add_to_class(:group, :set_tag_associations) do
    GroupTagAssociation.batch_set(self, @associated_tags)
  end

  add_to_class(:group, "associated_tags=") { |tag_names| @associated_tags = tag_names }

  add_to_class(:group, :associated_tags) do
    GroupTagAssociation.where(group_id: id).joins(:tag).pluck(:name)
  end

  reloadable_patch do
    Group.prepend(DiscourseGroupTagAssociations::GroupExtension)
    TopicQuery.prepend(DiscourseGroupTagAssociations::TopicQueryExtension)
    GroupsController.prepend(DiscourseGroupTagAssociations::GroupsControllerExtension)
  end

  add_to_serializer(:group_show, :associated_tags) do
    GroupTagAssociation.where(group_id: object.id).joins(:tag).pluck(:name)
  end
end
