# frozen_string_literal: true

class CreateGroupTagAssociations < ActiveRecord::Migration[6.0]
  def change
    create_table :group_tag_associations do |t|
      t.integer :group_id, null: false
      t.integer :tag_id, null: false
    end

    add_index :group_tag_associations,
              %i[group_id tag_id],
              unique: true,
              name: :idx_group_tag_associations_unique
  end
end
