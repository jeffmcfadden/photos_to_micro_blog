require "http"
require "json"

class MicroBlogClient
  MICROPUB_ENDPOINT = "https://micro.blog/micropub"

  attr_reader :config

  def initialize(api_key:)
    @api_key = api_key
    @config = {}
  end

  def get_config(force_update: false)
    return @config unless (@config.empty? || force_update)

    response = HTTP.auth("Bearer #{@api_key}").get("#{MICROPUB_ENDPOINT}?q=config")
    @config = JSON.parse(response.to_s)
  end

  # Uploads a file to the Micropub media endpoint.
  # @param file [String] Path to the file to upload.
  # @return [Hash] JSON response from the Micropub endpoint. Keys include `url` and `poster`
  def upload_file(file)
    # LOGGER.debug "Uploading file: #{file}"

    get_config

    response = HTTP.auth("Bearer #{@api_key}").post(@config["media-endpoint"], :form => {
      :file   => HTTP::FormData::File.new(file)
    })

    JSON.parse(response.to_s)
  end

  def page_html_for_gallery(gallery)
    html = ""

    gallery.photos.each do |photo|
      html += "<div class=\"photo\"><a href=\"#{photo.micro_blog_post_url}\"><img src=\"#{photo.micro_blog_image_url}\"></a></div>"
    end
    
    html
  end

  def create_page_for_gallery(gallery)
    payload = {
      type: [ "h-entry" ],
      "mp-channel" => "pages",
      "mp-navigation" => false,
      properties: {
        name: ["Gallery: #{gallery.group} - #{gallery.name}"],
        content: [page_html_for_gallery(gallery)],
      }
    }

    # LOGGER.debug "Payload: #{payload.to_json}"

    response = HTTP.auth("Bearer #{@api_key}")
                   .headers("Content-Type" => "application/json")
                   .post(MICROPUB_ENDPOINT, json: payload)

    data = JSON.parse(response.to_s)
    gallery.micro_blog_page_url = data["url"]
  end

  def update_page_for_gallery(gallery)
    payload = {
      action: "update",
      url: gallery.micro_blog_page_url,
      "replace": {
        "content": [page_html_for_gallery(gallery)]
      }
    }

    # LOGGER.debug "Payload: #{payload.to_json}"

    response = HTTP.auth("Bearer #{@api_key}")
                   .headers("Content-Type" => "application/json")
                   .post(MICROPUB_ENDPOINT, json: payload)

    # LOGGER.debug "Update Response: #{response.code} - #{response.to_s}"
  end

  def post_html_for_photo(photo)
    html = <<-HTML
<p><img src=\"#{photo.micro_blog_image_url}\" loading=\"lazy\"></p>
<p>#{photo.description}</p>
<p>#{photo.exif["City"]} #{photo.exif["Province-State"]} #{photo.taken_at.strftime("%B %d, %Y")}</p>
<p>#{photo.technical_meta}</p>
<p><a href=\"https://photos.thegreenshed.org/#{photo.cloud_storage_key}\">Download Original</a></p>
<p><a href=\"#{photo.gallery.micro_blog_page_url}\">View all photos in #{photo.gallery.name}</a></p>
HTML

    html
  end

  def create_post_for_photo(photo)
    LOGGER.info "Creating post for photo: #{photo.filepath}"

    payload = {
      type: [ "h-entry" ],
      properties: {
        name: [photo.title],
        content: [post_html_for_photo(photo)],
        published: [photo.taken_at.strftime("%Y-%m-%dT%H:%M:%S%:z")]
      }
    }

    # LOGGER.debug "Payload: #{payload.to_json}"

    response = HTTP.auth("Bearer #{@api_key}")
                   .headers("Content-Type" => "application/json")
                   .post(MICROPUB_ENDPOINT, json: payload)

    data = JSON.parse(response.to_s)
    photo.micro_blog_post_url = data["url"]
  end

  def update_post_for_photo(photo)
    LOGGER.info "Updating post for photo: #{photo.filepath}"

    payload = {
      action: "update",
      url: photo.micro_blog_post_url,
      "replace": {
        name: [photo.title],
        content: [post_html_for_photo(photo)],
        published: [photo.taken_at.strftime("%Y-%m-%dT%H:%M:%S%:z")]
      }
    }

    # LOGGER.debug "Payload: #{payload.to_json}"

    response = HTTP.auth("Bearer #{@api_key}")
                   .headers("Content-Type" => "application/json")
                   .post(MICROPUB_ENDPOINT, json: payload)

    # LOGGER.debug "Update Response: #{response.code} - #{response.to_s}"
    # photo.micro_blog_post_url = data["url"]
  end

  def update_page(url:,title:,content:,published_at:)
    payload = {
      action: "update",
      url: url,
      "replace": {
        name: [title],
        content: [content],
        published: [published_at.strftime("%Y-%m-%dT%H:%M:%S%:z")]
      }
    }

    resp = HTTP.auth("Bearer #{@api_key}")
        .headers("Content-Type" => "application/json")
        .post(MICROPUB_ENDPOINT, json: payload)

    puts "Response: #{resp.code} - #{resp.to_s}"
  end

end