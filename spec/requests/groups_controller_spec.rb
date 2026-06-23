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

  describe "#update" do
    fab!(:group_owner, :user)
    fab!(:regular_user, :user)
    fab!(:admin)
    fab!(:owned_group) { Fabricate(:group, users: [group_owner]) }

    fab!(:public_tag) { Fabricate(:tag, name: "public-tag") }
    fab!(:hidden_tag) { Fabricate(:tag, name: "hidden") }
    fab!(:hidden_tag_group) do
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
    end

    fab!(:public_topic_with_hidden_tag) { Fabricate(:topic, tags: [hidden_tag]) }
    fab!(:public_topic_with_public_tag) { Fabricate(:topic, tags: [public_tag]) }

    before { GroupUser.where(group: owned_group, user: group_owner).update_all(owner: true) }

    context "when a group owner tries to associate a tag" do
      it "should NOT allow associating hidden tags" do
        sign_in(group_owner)

        put "/groups/#{owned_group.id}.json",
            params: {
              group: {
                associated_tags: [hidden_tag.name],
              },
            }

        expect(response.status).to eq(200)

        owned_group.reload
        associated_tag_ids = GroupTagAssociation.where(group: owned_group).pluck(:tag_id)

        expect(associated_tag_ids).not_to include(hidden_tag.id)
      end

      it "should allow associating public tags" do
        sign_in(group_owner)

        put "/groups/#{owned_group.id}.json",
            params: {
              group: {
                associated_tags: [public_tag.name],
              },
            }

        expect(response.status).to eq(200)

        owned_group.reload
        associated_tag_ids = GroupTagAssociation.where(group: owned_group).pluck(:tag_id)

        expect(associated_tag_ids).to include(public_tag.id)
        expect(associated_tag_ids).not_to include(hidden_tag.id)
      end
    end

    context "when a user tries to discover topics via hidden tag association" do
      it "should NOT expose topics tagged with hidden tags (information disclosure test)" do
        sign_in(group_owner)

        GroupTagAssociation.create!(group: owned_group, tag: hidden_tag)

        get "/topics/groups/#{owned_group.name}.json"

        expect(response.status).to eq(200)
        topic_ids = response.parsed_body["topic_list"]["topics"].map { |t| t["id"] }

        expect(topic_ids).not_to include(public_topic_with_hidden_tag.id)
      end

      it "should expose topics tagged with public tags" do
        sign_in(group_owner)

        GroupTagAssociation.create!(group: owned_group, tag: public_tag)

        get "/topics/groups/#{owned_group.name}.json"

        expect(response.status).to eq(200)
        topic_ids = response.parsed_body["topic_list"]["topics"].map { |t| t["id"] }

        expect(topic_ids).to include(public_topic_with_public_tag.id)
        expect(topic_ids).not_to include(public_topic_with_hidden_tag.id)
      end
    end

    context "when viewing group details" do
      it "should NOT expose hidden tag names to unauthorized users" do
        sign_in(group_owner)

        GroupTagAssociation.create!(group: owned_group, tag: public_tag)
        GroupTagAssociation.create!(group: owned_group, tag: hidden_tag)

        get "/groups/#{owned_group.name}.json"

        expect(response.status).to eq(200)
        associated_tags = response.parsed_body["group"]["associated_tags"]

        expect(associated_tags).not_to include(hidden_tag.name)
        expect(associated_tags).to include(public_tag.name)
      end

      it "should expose all associated tags (including hidden) to admins" do
        sign_in(admin)

        GroupTagAssociation.create!(group: owned_group, tag: public_tag)
        GroupTagAssociation.create!(group: owned_group, tag: hidden_tag)

        get "/groups/#{owned_group.name}.json"

        expect(response.status).to eq(200)
        associated_tags = response.parsed_body["group"]["associated_tags"]

        expect(associated_tags).to include(hidden_tag.name)
        expect(associated_tags).to include(public_tag.name)
      end
    end

    it "prevents anonymous users from updating group tags" do
      put "/groups/#{owned_group.id}.json",
          params: {
            group: {
              associated_tags: [public_tag.name],
            },
          }

      expect(response.status).to eq(403)
    end

    it "prevents regular users (non-owners) from updating group tags" do
      sign_in(regular_user)

      put "/groups/#{owned_group.id}.json",
          params: {
            group: {
              associated_tags: [public_tag.name],
            },
          }

      expect(response.status).to eq(403)
    end

    it "allows staff to update any group tags" do
      sign_in(admin)

      put "/groups/#{owned_group.id}.json",
          params: {
            group: {
              associated_tags: [hidden_tag.name],
            },
          }

      expect(response.status).to eq(200)

      owned_group.reload
      associated_tag_ids = GroupTagAssociation.where(group: owned_group).pluck(:tag_id)

      expect(associated_tag_ids).to include(hidden_tag.id)
    end
  end
end
