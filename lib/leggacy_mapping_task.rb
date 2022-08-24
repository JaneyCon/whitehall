class LegacyMappingTask
  def fetch_all_legacy_taxons
    r = Services.publishing_api.get_linkables(document_type:"taxon")
    taxons = JSON.parse(r.raw_response_body)
    taxon_array =
      taxons.map do |taxon|
        {"content_id" => taxon["content_id"], "base_path" => taxon["base_path"]}
      end
    mappings =
      taxon_array.map do |taxon|
        r = Services.publishing_api.get_expanded_links(taxon["content_id"])
        json = JSON.parse(r.raw_response_body)
        unless json["expanded_links"]["legacy_taxons"].nil?
          {taxon["base_path"] => json["expanded_links"]["legacy_taxons"].first}
        end
      end
    CSV.open("data.csv", "wb") do |csv|
      mappings.compact.each do |mapping|
         csv << [mapping.keys.first, mapping.values.first["base_path"]]
      end
    end
  end
end
