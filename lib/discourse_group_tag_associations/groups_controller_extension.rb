# frozen_string_literal: true

module DiscourseGroupTagAssociations
  module GroupsControllerExtension
    extend ActiveSupport::Concern

    def group_params(automatic: false)
      core_params = super
      if params[:group][:associated_tags]
        core_params.merge!(associated_tags: params[:group][:associated_tags])
      else
        core_params
      end
    end
  end
end
