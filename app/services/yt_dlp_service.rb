require "open3"
require "json"

class YtDlpService
  class Error < StandardError; end

  Result = Struct.new(:filepath, :title, :filename, :file_size,
                      :thumbnail_url, :description, :duration, keyword_init: true)

  BINARY = ENV.fetch("YT_DLP_BIN", "yt-dlp")

  def initialize(url:, format:, output_dir:, quality: nil)
    @url = url
    @format = format
    @quality = quality
    @output_dir = output_dir
  end

  def call
    FileUtils.mkdir_p(@output_dir)
    metadata = fetch_metadata
    filepath = run_download
    filepath = remux_mp4(filepath) if @format == "mp4"
    Result.new(
      filepath: filepath,
      title: metadata["title"],
      filename: File.basename(filepath),
      file_size: File.size(filepath),
      thumbnail_url: metadata["thumbnail"],
      description: metadata["description"],
      duration: metadata["duration"]&.to_i
    )
  end

  private

  def fetch_metadata
    stdout, stderr, status = Open3.capture3(BINARY, "--dump-json", "--no-playlist", "--no-warnings", @url)
    raise Error, "Failed to fetch video metadata: #{stderr}" unless status.success?

    JSON.parse(stdout)
  end

  def run_download
    output_template = File.join(@output_dir, "%(title).150B [%(id)s].%(ext)s")
    args = base_args + format_args + ["-o", output_template, @url]
    stdout, stderr, status = Open3.capture3(BINARY, *args)
    raise Error, "yt-dlp failed: #{stderr.presence || stdout}" unless status.success?

    final_path = extract_final_path(stdout)
    raise Error, "Could not locate downloaded file" unless final_path && File.exist?(final_path)

    final_path
  end

  def base_args
    ["--no-playlist", "--no-warnings", "--no-progress", "--print", "after_move:filepath"]
  end

  def format_args
    case @format
    when "mp3"
      ["-x", "--audio-format", "mp3", "--audio-quality", "0"]
    when "mp4"
      selector = case @quality
                 when "720p"
                   "bestvideo[height<=720][ext=mp4][vcodec^=avc1]+bestaudio[ext=m4a]/best[height<=720][ext=mp4][vcodec^=avc1]/best[height<=720]"
                 else
                   "bestvideo[height<=1080][ext=mp4][vcodec^=avc1]+bestaudio[ext=m4a]/best[height<=1080][ext=mp4][vcodec^=avc1]/best[height<=1080]"
                 end
      ["-f", selector, "--merge-output-format", "mp4"]
    else
      raise Error, "Unsupported format: #{@format}"
    end
  end

  def extract_final_path(stdout)
    stdout.lines.map(&:strip).reject(&:empty?).last
  end

  # yt-dlp's merged mp4 is readable everywhere but chokes Adobe products (After
  # Effects / Premiere) — a trivial stream-copy remux through ffmpeg produces
  # an Adobe-friendly file. Lossless, ~instant.
  def remux_mp4(filepath)
    tmp_path = "#{filepath}.remux.mp4"
    _, stderr, status = Open3.capture3(
      "ffmpeg", "-y", "-loglevel", "error",
      "-i", filepath,
      "-c", "copy", "-map", "0",
      "-movflags", "+faststart",
      tmp_path
    )
    raise Error, "ffmpeg remux failed: #{stderr}" unless status.success?

    FileUtils.mv(tmp_path, filepath)
    filepath
  end
end
