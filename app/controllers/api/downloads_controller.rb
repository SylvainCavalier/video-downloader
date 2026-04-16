module Api
  class DownloadsController < BaseController
    before_action :set_download, only: %i[show destroy file]

    def index
      scope = policy_scope(Download).recent
      scope = scope.where(status: params[:status]) if params[:status].present?
      render json: scope.map { |d| serialize(d) }
    end

    def show
      authorize @download
      render json: serialize(@download)
    end

    def create
      @download = current_user.downloads.new(download_params.merge(status: "pending"))
      authorize @download
      if @download.save
        DownloadJob.perform_later(@download.id)
        render json: serialize(@download), status: :created
      else
        render json: { errors: @download.errors.full_messages }, status: :unprocessable_content
      end
    end

    def destroy
      authorize @download
      cleanup_files(@download)
      @download.destroy
      head :no_content
    end

    def file
      authorize @download, :file?
      if @download.local?
        path = local_filepath(@download)
        return render json: { error: "File missing" }, status: :gone unless path && File.exist?(path)

        send_file path, filename: @download.filename, disposition: "attachment"
      else
        redirect_to presigned_url(@download), allow_other_host: true
      end
    end

    private

    def set_download
      @download = policy_scope(Download).find(params[:id])
    end

    def download_params
      params.require(:download).permit(:url, :format, :quality, :storage, :folder_id)
    end

    def serialize(download)
      {
        id: download.id,
        url: download.url,
        format: download.format,
        quality: download.quality,
        storage: download.storage,
        status: download.status,
        title: download.title,
        filename: download.filename,
        file_size: download.file_size,
        folder_id: download.folder_id,
        error_message: download.error_message,
        completed_at: download.completed_at,
        created_at: download.created_at,
        file_url: download.completed? ? "/api/downloads/#{download.id}/file" : nil
      }
    end

    def local_filepath(download)
      dir = Rails.root.join("tmp", "downloads", download.id.to_s)
      File.join(dir, download.filename) if download.filename.present?
    end

    def presigned_url(download)
      signer = Aws::S3::Presigner.new(client: OvhS3.client)
      signer.presigned_url(:get_object,
                           bucket: OvhS3.bucket,
                           key: download.s3_key,
                           expires_in: 300,
                           response_content_disposition: %(attachment; filename="#{download.filename}"))
    end

    def cleanup_files(download)
      if download.local?
        FileUtils.rm_rf(Rails.root.join("tmp", "downloads", download.id.to_s))
      elsif download.cloud? && download.s3_key.present?
        OvhS3.client.delete_object(bucket: OvhS3.bucket, key: download.s3_key)
      end
    rescue StandardError => e
      Rails.logger.warn("Cleanup failed for download ##{download.id}: #{e.message}")
    end
  end
end
