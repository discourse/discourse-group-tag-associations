# frozen_string_literal: true

module DiscourseGroupTagAssociations
  module GroupUpdaterExtension
    extend ActiveSupport::Concern

    def update
      group.associated_tags_guardian = guardian if attributes.key?(:associated_tags)
      super
    end
  end
end
