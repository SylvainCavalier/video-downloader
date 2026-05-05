class AddMetadataToDownloads < ActiveRecord::Migration[8.0]
  def change
    add_column :downloads, :thumbnail_url, :string
    add_column :downloads, :description, :text
    add_column :downloads, :duration, :integer
  end
end
