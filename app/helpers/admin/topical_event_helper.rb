module Admin::TopicalEventHelper
  def topical_event_tabs(topical_event)
    {
      "Details" => url_for([:admin, topical_event]),
      "About page" => url_for([:admin, topical_event, :topical_event_about_pages]),
      "Features" => url_for([:admin, topical_event, :topical_event_featurings]),
    }
  end
end
