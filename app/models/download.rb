# == Schema Information
#
# Table name: downloads
#
#  id            :bigint           not null, primary key
#  completed_at  :datetime
#  error_message :text
#  file_size     :bigint
#  filename      :string
#  format        :string           not null
#  quality       :string
#  s3_key        :string
#  status        :string           default("pending"), not null
#  storage       :string           not null
#  title         :string
#  url           :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  folder_id     :bigint
#  user_id       :bigint           not null
#
# Indexes
#
#  index_downloads_on_folder_id           (folder_id)
#  index_downloads_on_user_id             (user_id)
#  index_downloads_on_user_id_and_status  (user_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (folder_id => folders.id)
#  fk_rails_...  (user_id => users.id)
#
class Download < ApplicationRecord
  FORMATS = %w[mp4 mp3].freeze
  QUALITIES = %w[original 720p].freeze
  STORAGES = %w[local cloud].freeze
  STATUSES = %w[pending processing completed failed].freeze

  belongs_to :user
  belongs_to :folder, optional: true

  validates :url, presence: true, format: { with: %r{\Ahttps?://}, message: "must be a valid URL" }
  validates :format, inclusion: { in: FORMATS }
  validates :quality, inclusion: { in: QUALITIES }, allow_nil: true
  validates :storage, inclusion: { in: STORAGES }
  validates :status, inclusion: { in: STATUSES }
  validate :quality_required_for_mp4
  validate :folder_only_for_cloud

  scope :recent, -> { order(created_at: :desc) }

  STATUSES.each do |state|
    define_method("#{state}?") { status == state }
  end

  def video?
    format == "mp4"
  end

  def audio?
    format == "mp3"
  end

  def cloud?
    storage == "cloud"
  end

  def local?
    storage == "local"
  end

  private

  def quality_required_for_mp4
    return unless format == "mp4"

    errors.add(:quality, "is required for mp4 downloads") if quality.blank?
  end

  def folder_only_for_cloud
    return if folder_id.blank?

    errors.add(:folder, "can only be set when storage is cloud") unless cloud?
  end
end
