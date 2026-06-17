# frozen_string_literal: true

describe GroupsController do
  before { SiteSetting.group_tag_associations_enabled = true }

  fab!(:user)
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

      expect(response.parsed_body["posts"].first["id"]).to eq(post.id)
    end

    fab!(:tag1) { Fabricate(:tag, name: "fun") }
    fab!(:tagged_topic) { Fabricate(:topic, tags: [tag1]) }

    it "`posts_for` includes posts from associated tags" do
      sign_in(user)

      tagged_post = Fabricate(:post, topic: tagged_topic)
      group.update(associated_tags: [tag1.name])

      get "/groups/#{group.name}/posts.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["posts"].first["id"]).to eq(tagged_post.id)
    end

    it "omits hidden posts from associated tags", :aggregate_failures do
      sign_in(user)

      visible_post = Fabricate(:post, topic: tagged_topic, raw: "visible tagged group post")
      hidden_post =
        Fabricate(:post, topic: tagged_topic, raw: "hidden tagged group post", hidden: true)
      group.update!(associated_tags: [tag1.name])

      get "/groups/#{group.name}/posts.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["posts"].map { |post| post["id"] }).to contain_exactly(
        visible_post.id,
      )
      expect(response.body).not_to include(hidden_post.raw)
    end

    it "still includes the viewer's own hidden posts from associated tags", :aggregate_failures do
      sign_in(user)

      own_hidden_post =
        Fabricate(:post, topic: tagged_topic, user: user, raw: "my own hidden post", hidden: true)
      group.update!(associated_tags: [tag1.name])

      get "/groups/#{group.name}/posts.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["posts"].map { |post| post["id"] }).to include(own_hidden_post.id)
    end

    it "includes hidden posts from associated tags for staff", :aggregate_failures do
      sign_in(Fabricate(:admin))

      hidden_post =
        Fabricate(:post, topic: tagged_topic, raw: "hidden tagged group post", hidden: true)
      group.update!(associated_tags: [tag1.name])

      get "/groups/#{group.name}/posts.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["posts"].map { |post| post["id"] }).to include(hidden_post.id)
    end

    it "omits hidden posts from associated tags for anonymous users", :aggregate_failures do
      visible_post = Fabricate(:post, topic: tagged_topic, raw: "visible tagged group post")
      hidden_post =
        Fabricate(:post, topic: tagged_topic, raw: "hidden tagged group post", hidden: true)
      group.update!(associated_tags: [tag1.name])

      get "/groups/#{group.name}/posts.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["posts"].map { |post| post["id"] }).to contain_exactly(
        visible_post.id,
      )
      expect(response.body).not_to include(hidden_post.raw)
    end
  end

  describe "#posts_feed" do
    fab!(:tag1) { Fabricate(:tag, name: "fun") }
    fab!(:tagged_topic) { Fabricate(:topic, tags: [tag1]) }

    it "omits hidden posts from associated tags", :aggregate_failures do
      sign_in(user)

      visible_post = Fabricate(:post, topic: tagged_topic, raw: "visible tagged group rss post")
      hidden_post =
        Fabricate(:post, topic: tagged_topic, raw: "hidden tagged group rss post", hidden: true)
      group.update!(associated_tags: [tag1.name])

      get "/groups/#{group.name}/posts.rss"

      expect(response.status).to eq(200)
      expect(response.body).to include(visible_post.raw)
      expect(response.body).not_to include(hidden_post.raw)
    end
  end
end
