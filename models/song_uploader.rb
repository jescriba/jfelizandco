require_relative '../globals'
require 'aws-sdk'
require 'fileutils'

class SongUploader
  include Globals
  @queue = :song_upload

  # UploadParams: file_params.merge({ :artist_name => artist_name,
  #                                     :song_name => song_name,
  #                                     :base_url => base_url,
  #                                     :lossy_url => lossy_url,
  #                                     :lossless_url => lossless_url,
  #                                     :is_lossless => lossless_url.empty?,
  #                                     :tempfile_path => file_params[:tempfile].path
  #                                  })
  def self.perform(upload_params)
    s3 = Aws::S3::Resource.new(region: 'us-west-1')

    # Ensure we are working w/ symbols
    upload_params = upload_params.reduce({}) { |memo, (k, v)| memo.merge({ k.to_sym => v}) }
    extension = File.extname(upload_params[:tempfile_path])
    tempfile = File.new(upload_params[:tempfile_path], "r")
    if upload_params[:is_lossless]
      lossless_object_path = upload_params[:lossless_url].sub(upload_params[:base_url], "")
      s3_lossless_object = s3.bucket(BUCKET).object(lossless_object_path)

      # upload
      s3_lossless_object.upload_file(tempfile, acl: 'public-read')
      s3_lossless_object.copy_to("#{s3_lossless_object.bucket.name}/#{s3_lossless_object.key}",
                              :metadata_directive => "REPLACE",
                              :acl => "public-read",
                              :content_type => upload_params[:type],
                              :content_disposition => "attachment; filename='#{upload_params[:song_name]}#{extension}'")

      # TODO Transcode
      # # transcode
      # lossy_object_path = upload_params[:lossy_url].chomp(upload_params[:base_url])
      # s3_lossy_object = s3.bucket(BUCKET).object(lossy_object_path)
      #
      # # upload
      # transcoded_file = ""
      # s3_lossy_object.upload_file(transcoded_file, acl: 'public-read')
      # s3_lossy_object.copy_to("#{s3_lossy_object.bucket.name}/#{s3_lossy_object.key}",
      #                         :metadata_directive => "REPLACE",
      #                         :acl => "public-read",
      #                         :content_type => "audio/mpeg",
      #                         :content_disposition => "attachment; filename='#{upload_params[:song_name]}#{extension}'")
    else
      lossy_object_path = upload_params[:lossy_url].chomp(upload_params[:base_url])
      s3_lossy_object = s3.bucket(BUCKET).object(lossy_object_path)

      # upload
      s3_lossy_object.upload_file(tempfile, acl: 'public-read')
      s3_lossy_object.copy_to("#{s3_lossy_object.bucket.name}/#{s3_lossy_object.key}",
                              :metadata_directive => "REPLACE",
                              :acl => "public-read",
                              :content_type => "audio/mpeg",
                              :content_disposition => "attachment; filename='#{upload_params[:song_name]}#{extension}'")
    end

    # Clean up - delete temp file
    FileUtils.rm([upload_params[:tempfile_path]])
  end
end
