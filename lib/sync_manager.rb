class SyncManager
  attr_reader :galleries, :config

  def initialize(config: {})
    @galleries = []
    @config = config
    @mb_client = MicroBlogClient.new(api_key: config["micro_blog_api_key"])
    @data_file = config["database_file"] || "db.json"
    @source_directory = config["source_directory"] || "galleries"
  end

  def load
    LOGGER.info "Loading data"

    load_saved_data
    load_galleries_from_disk

    LOGGER.info "Loaded #{galleries.size} total galleries."

    true
  end

  def save
    LOGGER.info "Saving data to #{@data_file}"

    File.open(@data_file, "w") do |f|
      f.write(JSON.pretty_generate({ galleries: @galleries.map(&:to_h) }))
    end
  end

  def load_saved_data
    data = JSON.load(File.read(@data_file))

    new_galleries = []
    data["galleries"].each do |gallery_data|
      gallery = Gallery.new(
        group: gallery_data["group"],
        name: gallery_data["name"],
        directory: gallery_data["directory"],
        micro_blog_page_url: gallery_data["micro_blog_page_url"],
        photos: gallery_data["photos"].map { |photo_data| Photo.new(filepath: photo_data["filepath"],
                                                                    cloud_storage_key: photo_data["cloud_storage_key"],
                                                                    micro_blog_image_url: photo_data["micro_blog_image_url"],
                                                                    micro_blog_post_url: photo_data["micro_blog_post_url"]) }
      )
      new_galleries << gallery
    end

    @galleries += new_galleries

    LOGGER.info "Loaded #{new_galleries.size} galleries from the database."
  end

  # Galleries are directories that contain the images.
  #
  # The file structure looks like this:
  # BASE_DIRECTORY
  # |- Group 1
  #    |- Gallery 1
  #       |- Image 1
  #       |- Image 2
  #       |- Image 3
  #    |- Gallery 2
  #       |- Image 4
  #       |- Image 5
  #       |- Image 6
  # |- Group 2
  #    |- Gallery 3
  #       |- Image 7
  #       |- Image 8
  #       |- Image 9
  #
  # For my purposes, Group is always a Year, like "2024" but there's no reason they couldn't be other
  # types of things.
  def load_galleries_from_disk
    directories = []
    Dir.foreach(@config["source_directory"]) do |filepath|
      next if filepath.start_with? "."
      next if filepath.start_with? "_"

      fullpath = File.expand_path(File.join(@config["source_directory"], filepath))

      next unless File.directory?( fullpath )

      LOGGER.debug("Found directory: #{fullpath}")
      directories << fullpath
    end

    new_galleries = []
    directories.each do |directory|
      LOGGER.debug("Processing directory: #{directory}")

      Dir.foreach(directory) do |filepath|
        next if filepath.start_with? "."
        next if filepath.start_with? "_"

        fullpath = File.expand_path(File.join(directory, filepath))
        next unless File.directory?( fullpath )

        components = fullpath.split(File::SEPARATOR).reject(&:empty?)
        group = components[-2]
        name = components[-1]

        next if gallery_exists?(group, name)

        new_galleries << Gallery.new(group: group, name: name, directory: fullpath)

        LOGGER.debug("Found directory. This should be a gallery: #{fullpath}")
      end
    end

    LOGGER.info "Loaded #{new_galleries.size} galleries from disk."

    @galleries += new_galleries
  end

  def gallery_exists?(group, name)
    galleries.any?{ |g| g.group == group && g.name == name }
  end

  def sync
    galleries.each do |gallery|
      sync_gallery(gallery)
    end

    update_gallery_index(galleries)
  end

  def sync_gallery(gallery)
    LOGGER.info("Syncing gallery: #{gallery}")

    # Create a page for the gallery
    if gallery.already_has_micro_blog_page?
      LOGGER.info "  Gallery Already has micro.blog page: #{gallery.micro_blog_page_url}."
    else
      create_page_for_gallery(gallery)
    end

    # Upload each photo to the micro.blog media endpoint
    gallery.photos.each_with_index do |photo, i|
      LOGGER.info "  Syncing photo: #{photo.filepath}"

      if photo.already_uploaded_to_micro_blog?
        LOGGER.info "    Already uploaded to micro.blog: #{photo.micro_blog_image_url}"
      else
        upload_photo_to_micro_blog(photo)
      end

      if photo.already_uploaded_to_cloud_storage?
        LOGGER.info "    Already uploaded to cloud storage: #{photo.cloud_storage_key}"
      else
        upload_photo_to_cloud_storage(photo)
      end

      if photo.already_has_post?
        LOGGER.info "    Already has post: #{photo.micro_blog_post_url}"
        @mb_client.update_post_for_photo(photo)
      else
        create_post_for_photo(photo)
      end

    rescue => e
      LOGGER.error "Error syncing photo: #{photo.filepath}: #{e}"

      save
    end

    # Create a page for the gallery
    LOGGER.info "  Updating gallery page now that photos are ready: #{gallery.micro_blog_page_url}."
    @mb_client.update_page_for_gallery(gallery)

    save
  end


  def create_post_for_photo(photo)
    resp = @mb_client.create_post_for_photo(photo)
    # LOGGER.debug "create_post_for_photo Response: #{resp}"
  end

  def create_page_for_gallery(gallery)
    resp = @mb_client.create_page_for_gallery(gallery)
    # LOGGER.debug "create_page_for_gallery Response: #{resp}"
  end

  def upload_photo_to_micro_blog(photo)
    LOGGER.info("  Uploading photo to micro.blog: (#{File.mb_size(photo.filepath).round(1)} MB)")
    data = @mb_client.upload_file(photo.filepath)

    photo.micro_blog_image_url = data["url"]
  end

  def upload_photo_to_cloud_storage(photo)
    LOGGER.info("    Uploading photo to cloud storage: (#{File.mb_size(photo.filepath).round(1)} MB)")

    key = "#{photo.gallery.group}/#{photo.gallery.name}/#{File.basename(photo.filepath)}"
    LOGGER.info "      Key: #{key}"

    # Upload the file
    obj = s3.bucket(@config["cloud_storage"]["bucket_name"]).object(key)
    obj.upload_file(photo.filepath)

    photo.cloud_storage_key = key
  end

  def update_gallery_index(galleries)
    LOGGER.info "Updating gallery index page"

    url = "https://thegreenshed.org/photography/"
    title = "Photography"
    content = <<-HTML
<h1>Galleries</h1>
<div class="galleries">
#{galleries.map{ |g| "<a href=\"#{g.micro_blog_page_url}\">#{g.group} - #{g.name}</a>" }.join("<br />")}
</div>
    HTML

    @mb_client.update_page(url: url, title: title, content: content, published_at: DateTime.now)
  end

  private

  def s3
    # Initialize the S3 client
    @s3 ||= Aws::S3::Resource.new(
      region: 'auto',
      access_key_id: @config["cloud_storage"]["access_key"],
      secret_access_key: @config["cloud_storage"]["secret_key"],
      endpoint: @config["cloud_storage"]["endpoint"],
      force_path_style: true # Necessary for many S3-compatible services
    )
  end


end