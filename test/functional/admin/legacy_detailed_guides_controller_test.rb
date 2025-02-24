require "test_helper"

class Admin::LegacyDetailedGuidesControllerTest < ActionController::TestCase
  tests Admin::DetailedGuidesController

  include GdsApi::TestHelpers::PublishingApi

  setup do
    login_as create(:writer, organisation: create(:organisation))
    create(:government)
    stub_request(
      :get,
      %r{\A#{Plek.find('publishing-api')}/v2/links},
    ).to_return(body: { links: {} }.to_json)
    stub_publishing_api_has_linkables([], document_type: "need")
  end

  legacy_should_be_an_admin_controller

  legacy_should_allow_creating_of :detailed_guide
  legacy_should_allow_editing_of :detailed_guide

  legacy_should_allow_organisations_for :detailed_guide
  legacy_should_allow_attached_images_for :detailed_guide
  legacy_should_prevent_modification_of_unmodifiable :detailed_guide
  legacy_should_allow_association_with_related_mainstream_content :detailed_guide
  legacy_should_allow_alternative_format_provider_for :detailed_guide
  legacy_should_allow_scheduled_publication_of :detailed_guide
  legacy_should_allow_overriding_of_first_published_at_for :detailed_guide
  legacy_should_allow_access_limiting_of :detailed_guide

  view_test "user needs associated with a detailed guide" do
    content_id_a = SecureRandom.uuid
    content_id_b = SecureRandom.uuid

    detailed_guide = create(:detailed_guide)
    stub_publishing_api_has_links(
      {
        content_id: detailed_guide.document.content_id,
        links: {
          meets_user_needs: [content_id_a, content_id_b],
        },
      },
    )
    stub_publishing_api_has_expanded_links(
      {
        content_id: detailed_guide.document.content_id,
        expanded_links: {
          taxons: [],
          meets_user_needs: [
            {
              content_id: content_id_a,
              details: {
                role: "x",
                goal: "y",
                benefit: "z",
              },
            },
            {
              content_id: content_id_b,
              details: {
                role: "c",
                goal: "d",
                benefit: "e",
              },
            },
          ],
        },
        version: 1,
      },
    )

    get :show, params: { id: detailed_guide.id }

    assert_select "#user-needs-section" do |_section|
      assert_select "#user-need-id-#{content_id_a}" do
        assert_select ".description", text: "As a x,\n    I need to y,\n    So that z"
        assert_select ".maslow-url[href*='#{content_id_a}']"
      end

      assert_select "#user-need-id-#{content_id_b}" do
        assert_select ".description", text: "As a c,\n    I need to d,\n    So that e"
        assert_select ".maslow-url[href*='#{content_id_b}']"
      end
    end
  end

private

  def controller_attributes_for(edition_type, attributes = {})
    super.except(:alternative_format_provider).reverse_merge(
      alternative_format_provider_id: create(:alternative_format_provider).id,
    )
  end
end
