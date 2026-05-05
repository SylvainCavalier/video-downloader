class DownloadJob < ApplicationJob
  queue_as :default

  CONTENT_TYPES = {
    "mp4" => "video/mp4",
    "mp3" => "audio/mpeg"
  }.freeze

  def perform(download_id)
    download = Download.find(download_id)
    return unless download.pending?

    download.update!(status: "processing")

    result = YtDlpService.new(
      url: download.url,
      format: download.format,
      quality: download.quality,
      output_dir: local_dir_for(download)
    ).call

    download.assign_attributes(
      title: result.title,
      filename: result.filename,
      file_size: result.file_size,
      thumbnail_url: result.thumbnail_url,
      description: result.description,
      duration: result.duration
    )

    if download.cloud?
      upload_to_s3(download, result.filepath)
      FileUtils.rm_f(result.filepath)
      begin
        FileUtils.rmdir(local_dir_for(download))
      rescue StandardError
        nil
      end
    end

    download.update!(status: "completed", completed_at: Time.current)
  rescue StandardError => e
    Rails.logger.error("DownloadJob failed for ##{download_id}: #{e.class}: #{e.message}")
    Download.where(id: download_id).update_all(
      status: "failed",
      error_message: "#{e.class}: #{e.message}".truncate(1000)
    )
    FileUtils.rm_rf(local_dir_for_id(download_id))
    raise
  end

  private

  def local_dir_for(download)
    local_dir_for_id(download.id)
  end

  def local_dir_for_id(id)
    Rails.root.join("tmp", "downloads", id.to_s).to_s
  end

  def upload_to_s3(download, filepath)
    key = s3_key_for(download)
    File.open(filepath, "rb") do |file|
      OvhS3.client.put_object(
        bucket: OvhS3.bucket,
        key: key,
        body: file,
        content_type: CONTENT_TYPES[download.format]
      )
    end
    download.s3_key = key
  end

  def s3_key_for(download)
    folder_segment = download.folder&.name&.parameterize.presence || "unsorted"
    "downloads/user-#{download.user_id}/#{folder_segment}/#{download.id}-#{download.filename}"
  end
end
