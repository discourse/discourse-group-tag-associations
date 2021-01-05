# frozen_string_literal: true

require 'rails_helper'

describe Group do
  before do
    SiteSetting.group_tag_associations_enabled = true
  end

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

  describe "batch_set" do
    fab!(:funtag) { Fabricate(:tag, name: "fun") }
    fab!(:funtag2) { Fabricate(:tag, name: "fun2") }
    fab!(:funtag3) { Fabricate(:tag, name: "fun3") }

    it "handles adding and removing tags to a group corectly" do
      group.update(associated_tags: [funtag.name, funtag2.name])
      expect(group.associated_tags).to eq([funtag.name, funtag2.name])

      group.update(associated_tags: [funtag3.name])
      expect(group.associated_tags).to eq([funtag3.name])

      group.update(associated_tags: nil)
      expect(group.associated_tags).to eq([])

      group.update(associated_tags: [funtag.name, funtag2.name, funtag3.name])
      expect(group.associated_tags.length).to eq(3)

      group.update(associated_tags: [])
      expect(group.associated_tags).to eq([])
    end
  end
end
