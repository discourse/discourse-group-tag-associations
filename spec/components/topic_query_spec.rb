# frozen_string_literal: true

require 'rails_helper'

describe TopicQuery do
  before do
    SiteSetting.group_tag_associations_enabled = true
  end

  describe '#list_group_topics' do
    fab!(:group) { Fabricate(:group) }

    let(:user) do
      user = Fabricate(:user)
      group.add(user)
      user
    end

    let(:user2) do
      user = Fabricate(:user)
      group.add(user)
      user
    end

    fab!(:user3) { Fabricate(:user) }

    fab!(:private_category) do
      Fabricate(:private_category_with_definition, group: group)
    end

    let!(:private_message_topic) { Fabricate(:private_message_post, user: user).topic }
    let!(:topic1) { Fabricate(:topic, user: user) }
    let!(:topic2) { Fabricate(:topic, user: user, category: Fabricate(:category_with_definition)) }
    let!(:topic3) { Fabricate(:topic, user: user, category: private_category) }
    let!(:topic4) { Fabricate(:topic) }
    let!(:topic5) { Fabricate(:topic, user: user, visible: false) }
    let!(:topic6) { Fabricate(:topic, user: user2) }

    it 'should return the right lists for anon user' do
      topics = TopicQuery.new.list_group_topics(group).topics

      expect(topics).to contain_exactly(topic1, topic2, topic6)
    end

    it 'should retun the right list for users in the same group' do
      topics = TopicQuery.new(user).list_group_topics(group).topics

      expect(topics).to contain_exactly(topic1, topic2, topic3, topic6)

      topics = TopicQuery.new(user2).list_group_topics(group).topics

      expect(topics).to contain_exactly(topic1, topic2, topic3, topic6)
    end

    it 'should return the right list for user not in the group' do
      topics = TopicQuery.new(user3).list_group_topics(group).topics

      expect(topics).to contain_exactly(topic1, topic2, topic6)
    end

    # specs above are same as core, to make sure core functionalities don't regress

    fab!(:tag1) { Fabricate(:tag, name: "fun") }
    fab!(:tag2) { Fabricate(:tag, name: "fun2") }
    fab!(:tag_unused) { Fabricate(:tag, name: "unused") }
    fab!(:tag1_topic) { Fabricate(:topic, tags: [tag1]) }
    fab!(:tag2_topic) { Fabricate(:topic, tags: [tag2]) }

    it 'should include topics with tags matching group associated tags' do
      group.update(associated_tags: [tag1.name, tag2.name])
      topics = TopicQuery.new(user).list_group_topics(group).topics

      expect(topics).to contain_exactly(tag1_topic, tag2_topic)
    end

    it 'should be empty if group has an associated tag but no topics are tagged' do
      group.update(associated_tags: [tag_unused.name])
      topics = TopicQuery.new(user).list_group_topics(group).topics

      expect(topics).to be_empty
    end
  end
end
