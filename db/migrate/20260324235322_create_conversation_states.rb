class CreateConversationStates < ActiveRecord::Migration[8.1]
  def change
    create_table :conversation_states do |t|
      t.references :user, null: false, foreign_key: true
      t.string :channel, null: false
      t.string :channel_user_id, null: false
      t.integer :step, default: 0, null: false
      t.jsonb :data, default: {}
      t.references :service_request, foreign_key: true  # nullable — solo se llena cuando se crea la solicitud
      t.datetime :expires_at

      t.timestamps
    end

    add_index :conversation_states, [:channel, :channel_user_id], unique: true
    add_index :conversation_states, :step
  end
end
