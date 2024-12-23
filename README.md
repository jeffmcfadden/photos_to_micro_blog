## Description

Sync a directory of photo galleries to Micro.blog

## Motive

I really enjoy [Micro.blog](https://micro.blog), but I'm also super picky about
how I want my photos handled. I like my photos grouped into galleries, with 
a post for each photo, and a gallery index. I also want to make original 
full-size files available for download. MB does _some_ of this, but again, 
I'm super picky, so I wanted a tool to give me what I wanted, exactly. This 
lets me do that.

## Setup

Create your `.env` file (and replace with your own variables):

    MICRO_BLOG_TOKEN = "asdf"
    SOURCE_DIRECTORY = "/Users/coolcat/Pictures/Galleries"
    DB_FILE = "db.json"
    R2_ACCESS_KEY = "asdfasdf"
    R2_SECRET_KEY = "asdfasdfasd"
    R2_ENDPOINT = "https://asdfasdfasdf.r2.cloudflarestorage.com"
    R2_BUCKET_NAME = "coolcat-photos"
    CLOUD_STORAGE_HOSTNAME = "photos.example.com"


    $ bundle install

## Sync

    $ bundle exec ruby sync.rb