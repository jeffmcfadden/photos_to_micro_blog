class Gallery
  attr_accessor :group, :name, :directory, :photos, :micro_blog_page_url

  SUPPORTED_FILE_FORMATS = %w(.jpg .jpeg .jxl .avif)

  def initialize(group:, name:, directory:, micro_blog_page_url: nil, photos: [])
    @group = group
    @name = name
    @directory = directory
    @micro_blog_page_url = micro_blog_page_url
    @photos = photos

    @photos.each{ |photo| photo.gallery = self }

    load_photos_from_disk
  end

  def already_has_micro_blog_page?
    !@micro_blog_page_url.nil?
  end

  def to_h
      {
        group: @group,
        name: @name,
        directory: @directory,
        micro_blog_page_url: @micro_blog_page_url,
        photos: @photos.map(&:to_h)
    }
  end

  def to_s
    "Gallery <#{object_id}> #{@group} - #{@name}. #{@photos.size} photos."
  end

  def load_photos_from_disk
    Dir.foreach(@directory) do |filepath|
      next if filepath.start_with? "."
      next if filepath.start_with? "_"
      next if @photos.any?{ |photo| photo.filepath == File.join(@directory, filepath) } # Skip if we already have this photo
      next unless File.extname(filepath).in? SUPPORTED_FILE_FORMATS

      @photos << Photo.new(gallery: self, filepath: File.join(@directory, filepath))
    end

    @photos
  end

end