class CreateDownloads < ActiveRecord::Migration[8.0]
  def change
    create_table :downloads do |t|
      t.references :user, null: false, foreign_key: true
      t.references :folder, null: true, foreign_key: true
      t.string :url, null: false
      t.string :format, null: false
      t.string :quality
      t.string :storage, null: false
      t.string :status, null: false, default: "pending"
      t.string :title
      t.string :filename
      t.bigint :file_size
      t.string :s3_key
      t.text :error_message
      t.datetime :completed_at

      t.timestamps
    end

    add_index :downloads, [:user_id, :status]
  end
end
