# frozen_string_literal: true

require_dependency 'groups_controller'

class GroupsController < ApplicationController

  private
  alias_method :original_group_params, :group_params

  def group_params(automatic: false)
    core_params = original_group_params(automatic: automatic)
    if params[:group][:associated_tags]
      core_params.merge!(associated_tags: params[:group][:associated_tags])
    else
      core_params
    end
  end

end
