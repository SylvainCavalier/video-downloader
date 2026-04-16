module Api
  class FoldersController < BaseController
    before_action :set_folder, only: %i[show update destroy]

    def index
      @folders = policy_scope(Folder).order(:name)
      render json: @folders.map { |f| serialize(f) }
    end

    def show
      authorize @folder
      render json: serialize(@folder)
    end

    def create
      @folder = current_user.folders.new(folder_params)
      authorize @folder
      if @folder.save
        render json: serialize(@folder), status: :created
      else
        render json: { errors: @folder.errors.full_messages }, status: :unprocessable_content
      end
    end

    def update
      authorize @folder
      if @folder.update(folder_params)
        render json: serialize(@folder)
      else
        render json: { errors: @folder.errors.full_messages }, status: :unprocessable_content
      end
    end

    def destroy
      authorize @folder
      @folder.destroy
      head :no_content
    end

    private

    def set_folder
      @folder = policy_scope(Folder).find(params[:id])
    end

    def folder_params
      params.require(:folder).permit(:name)
    end

    def serialize(folder)
      {
        id: folder.id,
        name: folder.name,
        downloads_count: folder.downloads.count,
        created_at: folder.created_at
      }
    end
  end
end
