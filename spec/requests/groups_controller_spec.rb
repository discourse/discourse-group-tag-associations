# frozen_string_literal: true

require "rails_helper"

describe GroupsController do
  before { SiteSetting.group_tag_associations_enabled = true }

  fab!(:user) { Fabricate(:user) }
  let(:group) { Fabricate(:group, users: [user]) }

  describe "#posts" do
    it "ensures the group can be seen" do
      sign_in(Fabricate(:user))
      group.update!(visibility_level: Group.visibility_levels[:owners])

      get "/groups/#{group.name}/posts.json"

      expect(response.status).to eq(404)
    end

    it "ensures the group members can be seen" do
      sign_in(Fabricate(:user))
      group.update!(members_visibility_level: Group.visibility_levels[:owners])

      get "/groups/#{group.name}/posts.json"

      expect(response.status).to eq(403)
    end

    it "calls `posts_for` and responds with JSON" do
      sign_in(user)
      post = Fabricate(:post, user: user)
      get "/groups/#{group.name}/posts.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body.first["id"]).to eq(post.id)
    end

    fab!(:tag1) { Fabricate(:tag, name: "fun") }
    fab!(:tagged_topic) { Fabricate(:topic, tags: [tag1]) }

    it "`posts_for` includes posts from associated tags" do
      sign_in(user)

      tagged_post = Fabricate(:post, topic: tagged_topic)
      group.update(associated_tags: [tag1.name])

      get "/groups/#{group.name}/posts.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body.first["id"]).to eq(tagged_post.id)
    end
  end
end
