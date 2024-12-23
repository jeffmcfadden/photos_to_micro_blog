class Photo
  attr_accessor :gallery, :filepath, :cloud_storage_key, :micro_blog_image_url, :micro_blog_post_url

  def initialize(gallery: nil, filepath:, cloud_storage_key: nil, micro_blog_image_url: nil, micro_blog_post_url: nil)
    @gallery = gallery
    @filepath = filepath
    @cloud_storage_key = cloud_storage_key
    @micro_blog_image_url = micro_blog_image_url
    @micro_blog_post_url = micro_blog_post_url
  end

  def already_has_post?
    !@micro_blog_post_url.nil?
  end

  def already_uploaded_to_micro_blog?
    !@micro_blog_image_url.nil?
  end

  def already_uploaded_to_cloud_storage?
    !@cloud_storage_key.nil?
  end

  def to_h
    {
      filepath: @filepath,
      cloud_storage_key: @cloud_storage_key,
      micro_blog_image_url: @micro_blog_image_url,
      micro_blog_post_url: @micro_blog_post_url
    }
  end

  def to_s
    "Image <#{object_id}> #{@filepath} : #{@micro_blog_image_url} (#{@micro_blog_post_url}) (#{@cloud_storage_key})"
  end

  def exif
    @exif ||= JSON.parse(`exiftool -json "#{filepath}"`)[0]
  end

  def taken_at
    @taken_at ||= DateTime.strptime(exif["CreateDate"], "%Y:%m:%d %H:%M:%S")
  rescue => e
    LOGGER.error "Error parsing EXIF CreateDate for #{@filepath}: #{e}. Using File mtime instead."
    return File.new(filepath).mtime
  end

  def title
    exif["Title"] || exif["ObjectName"] || ""
  end

  def description
    exif["Description"] || exif["ImageDescription"] || ""
  end

  def technical_meta
    meta = <<-META
  
  <br />Camera: #{exif["Make"]} #{exif["Model"]}
  <br />Lens: #{exif["LensModel"]}
  <br />Focal Length: #{exif["FocalLength"]}
  <br />Aperture: f/#{exif["FNumber"]}
  <br />Shutter Speed: #{exif["ShutterSpeedValue"]}
  <br />ISO: #{exif["ISO"]}
  <br />Exposure Compensation: #{exif["ExposureCompensation"]}

    META

    meta
  end

  # EXIF Values I tend to care about:
  # CreateDate => "2024:10:11 08:01:46"
  #   "ShutterSpeedValue": "1/80",
  #   "ApertureValue": 1.8,
  #   "FocalLength": "35.0 mm",
  #   "LensInfo": "35mm f/1.8",
  #   "LensModel": "FE 35mm F1.8",
  # "Rating": 3,
  #   "GPSDateTime": "2024:10:11 08:01:46Z",
  #   "GPSLatitude": "34 deg 39' 17.46\" N",
  #   "GPSLongitude": "135 deg 25' 43.91\" E",
  #   "Make": "SONY",
  #   "Model": "ILCE-7RM4A",
  #   "ExposureTime": "1/80",
  #   "FNumber": 1.8,
  #   "ExposureProgram": "Aperture-priority AE",
  # "ExposureCompensation": -2,

end
