# frozen_string_literal: true

require 'rails_helper'

describe Group do
  let(:user) { Fabricate(:user) }
  let(:user2) { Fabricate(:user) }
  let(:group) { Fabricate(:group) }

  describe "#posts_for" do
    it "returns the post in the group" do
      p = Fabricate(:post)
      group.add(p.user)

      posts = group.posts_for(Guardian.new)
      expect(posts).to include(p)
    end

    it "doesn't include unlisted posts" do
      p = Fabricate(:post)
      p.topic.update_column(:visible, false)
      group.add(p.user)

      posts = group.posts_for(Guardian.new)
      expect(posts).not_to include(p)
    end

    # specs above are same as core, to ensure core functionalities don't regress

    fab!(:tag1) { Fabricate(:tag, name: "fun") }
    fab!(:tag2) { Fabricate(:tag, name: "fun2") }
    fab!(:tagged_topic) { Fabricate(:topic, tags: [tag1, tag2]) }
    fab!(:tagged_post) { Fabricate(:post, topic: tagged_topic) }

    it "includes a post with associated tags" do
      group.update(associated_tags: [tag1.name])
      posts = group.posts_for(Guardian.new)

      expect(posts).to include(tagged_post)
    end

    it "includes a mix of groups posts and posts with associated tags" do
      p = Fabricate(:post)
      group.add(p.user)
      group.update(associated_tags: [tag1.name])

      posts = group.posts_for(Guardian.new)

      expect(posts).to include(tagged_post)
      expect(posts).to include(p)
    end
  end
end
