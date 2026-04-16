require "aws-sdk-s3"

module OvhS3
  class << self
    def client
      @client ||= Aws::S3::Client.new(
        access_key_id: ENV.fetch("OVH_S3_ACCESS_KEY"),
        secret_access_key: ENV.fetch("OVH_S3_SECRET_KEY"),
        region: ENV.fetch("OVH_S3_REGION").downcase,
        endpoint: ENV.fetch("OVH_S3_ENDPOINT"),
        force_path_style: false
      )
    end

    def bucket
      ENV.fetch("OVH_S3_BUCKET")
    end

    def reset!
      @client = nil
    end
  end
end
