class AssetManagerCreateWhitehallAssetWorker < WorkerBase
  def perform(file_path, legacy_url_path, draft = false, model_class = nil, model_id = nil)
    file = File.open(file_path)
    asset_options = { file: file, legacy_url_path: legacy_url_path }
    asset_options[:draft] = true if draft

    if model_class && model_id
      model = model_class.constantize.find(model_id)
      if model.respond_to?(:attachable_is_access_limited?)
        if model.attachable_is_access_limited?
          authorised_user_uids = AssetManagerAccessLimitation.for(model.access_limited_object)
          asset_options[:access_limited] = authorised_user_uids
        end
      end
    end

    Services.asset_manager.create_whitehall_asset(asset_options)
    FileUtils.rm(file)
    FileUtils.rmdir(File.dirname(file))
  end
end
