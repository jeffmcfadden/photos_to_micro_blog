require "logger"
require "aws-sdk-s3"
require "http"
require "dotenv"
require_relative "lib/_support"
require_relative "lib/micro_blog_client"
require_relative "lib/gallery"
require_relative "lib/photo"
require_relative "lib/sync_manager"

Dotenv.load

LOGGER = Logger.new(STDOUT)

@sync_manager = SyncManager.new(config: { "micro_blog_api_key" => ENV["MICRO_BLOG_TOKEN"],
                                          "source_directory" => ENV["SOURCE_DIRECTORY"],
                                          "database_file" => ENV["DB_FILE"],
                                          "cloud_storage" => {
                                            "access_key" => ENV["R2_ACCESS_KEY"],
                                            "secret_key" => ENV["R2_SECRET_KEY"],
                                            "endpoint" => ENV["R2_ENDPOINT"],
                                            "bucket_name" => ENV["R2_BUCKET_NAME"]
                                          }
})

@sync_manager.load
@sync_manager.sync
@sync_manager.save
