require "test_helper"

class Admin::LegacyConsultationsControllerTest < ActionController::TestCase
  tests Admin::ConsultationsController
  include TaxonomyHelper

  setup do
    login_as :writer
    ConsultationResponseForm.any_instance.stubs(:consultation_participation).returns(stub(consultation: stub(auth_bypass_id: "auth bypass id")))
  end

  legacy_should_be_an_admin_controller

  legacy_should_allow_creating_of :consultation
  legacy_should_allow_editing_of :consultation

  legacy_should_allow_speed_tagging_of :consultation
  legacy_should_allow_organisations_for :consultation
  legacy_should_allow_attached_images_for :consultation
  legacy_should_prevent_modification_of_unmodifiable :consultation
  legacy_should_allow_alternative_format_provider_for :consultation
  legacy_should_allow_scheduled_publication_of :consultation
  legacy_should_allow_access_limiting_of :consultation

  view_test "new displays consultation fields" do
    get :new

    assert_select "form#new_edition" do
      assert_select "textarea[name='edition[summary]']"
      assert_select "select[name*='edition[opening_at']", count: 5
      assert_select "select[name*='edition[closing_at']", count: 5
      assert_select "input[type='text'][name='edition[consultation_participation_attributes][link_url]']"
      assert_select "input[type='text'][name='edition[consultation_participation_attributes][email]']"
      assert_select "input[type='text'][name='edition[consultation_participation_attributes][consultation_response_form_attributes][title]']"
      assert_select "input[type='file'][name='edition[consultation_participation_attributes][consultation_response_form_attributes][consultation_response_form_data_attributes][file]']"
    end
  end

  test "create should create a new consultation" do
    attributes = controller_attributes_for(
      :consultation,
      consultation_participation_attributes: {
        link_url: "http://participation.com",
        email: "countmein@participation.com",
        consultation_response_form_attributes: {
          title: "the title of the response form",
          consultation_response_form_data_attributes: {
            file: upload_fixture("two-pages.pdf"),
          },
        },
      },
    )

    post :create, params: { edition: attributes }

    consultation = Consultation.last
    response_form = consultation.consultation_participation.consultation_response_form
    assert_equal attributes[:summary], consultation.summary
    assert_equal attributes[:opening_at], consultation.opening_at
    assert_equal attributes[:closing_at], consultation.closing_at
    assert_equal "http://participation.com", consultation.consultation_participation.link_url
    assert_equal "countmein@participation.com", consultation.consultation_participation.email
    assert_equal "the title of the response form", response_form.title
    assert response_form.consultation_response_form_data.file.present?
  end

  test "create should create a new consultation without consultation participation if participation fields are all blank" do
    attributes = controller_attributes_for(
      :consultation,
      consultation_participation_attributes: {
        link_url: nil,
        email: nil,
        consultation_response_form_attributes: {
          title: nil,
          consultation_response_form_data_attributes: {
            file: nil,
          },
        },
      },
    )

    post :create, params: { edition: attributes }

    consultation = Consultation.last
    assert_nil consultation.consultation_participation
  end

  view_test "creating a consultation with invalid data but valid form file should still display the cached form file" do
    attributes = controller_attributes_for(
      :consultation,
      consultation_participation_attributes: {
        link_url: nil,
        email: nil,
        consultation_response_form_attributes: {
          title: nil,
          consultation_response_form_data_attributes: {
            file: upload_fixture("two-pages.pdf"),
          },
        },
      },
    )

    post :create, params: { edition: attributes }

    assert_select "form#new_edition" do
      assert_select "input[name='edition[consultation_participation_attributes][consultation_response_form_attributes][consultation_response_form_data_attributes][file_cache]'][value$='two-pages.pdf']"
      assert_select ".already_uploaded", text: "two-pages.pdf already uploaded"
    end
  end

  view_test "show renders the summary" do
    draft_consultation = create(:draft_consultation, summary: "a-simple-summary")
    stub_publishing_api_expanded_links_with_taxons(draft_consultation.content_id, [])

    get :show, params: { id: draft_consultation }
    assert_select ".page-header .lead", text: "a-simple-summary"
  end

  view_test "edit displays consultation fields" do
    response_form = create(:consultation_response_form)
    participation = create(:consultation_participation, consultation_response_form: response_form)
    consultation = create(:consultation, consultation_participation: participation)

    get :edit, params: { id: consultation }

    assert_select "form#edit_edition" do
      assert_select "textarea[name='edition[summary]']"
      assert_select "select[name*='edition[opening_at']", count: 5
      assert_select "select[name*='edition[closing_at']", count: 5
      assert_select "input[type='text'][name='edition[consultation_participation_attributes][link_url]']"
      assert_select "input[type='text'][name='edition[consultation_participation_attributes][email]']"
      assert_select "textarea[name='edition[consultation_participation_attributes][postal_address]']"
      assert_select "input[type='hidden'][name='edition[consultation_participation_attributes][consultation_response_form_attributes][id]'][value='#{response_form.id}']"
      assert_select "input[type='text'][name='edition[consultation_participation_attributes][consultation_response_form_attributes][title]']"
      assert_select "input[type='hidden'][name='edition[consultation_participation_attributes][consultation_response_form_attributes][consultation_response_form_data_attributes][id]'][value='#{response_form.consultation_response_form_data.id}']"
      assert_select "input[type='file'][name='edition[consultation_participation_attributes][consultation_response_form_attributes][consultation_response_form_data_attributes][file]']"
    end
  end

  test "update should save modified consultation attributes" do
    consultation = create(:consultation)

    put :update,
        params: { id: consultation,
                  edition: {
                    summary: "new-summary",
                    opening_at: 1.day.ago,
                    closing_at: 50.days.from_now,
                    consultation_participation_attributes: {
                      link_url: "http://consult.com",
                      email: "tell-us-what-you-think@gov.uk",
                    },
                  } }

    consultation.reload
    assert_equal "new-summary", consultation.summary
    assert_equal 1.day.ago, consultation.opening_at
    assert_equal 50.days.from_now, consultation.closing_at
    assert_equal "http://consult.com", consultation.consultation_participation.link_url
    assert_equal "tell-us-what-you-think@gov.uk", consultation.consultation_participation.email
  end

  test "update should save consultation without consultation participation if participation fields are all blank" do
    consultation = create(:consultation)

    put :update,
        params: { id: consultation,
                  edition: {
                    consultation_participation_attributes: {
                      link_url: nil,
                      email: nil,
                    },
                  } }

    consultation.reload
    assert_nil consultation.consultation_participation
  end

  view_test "updating should not allow removal of response form without explicit action" do
    response_form = create(:consultation_response_form)
    participation = create(:consultation_participation, consultation_response_form: response_form)
    consultation = create(:consultation, consultation_participation: participation)

    put :update,
        params: { id: consultation,
                  edition: {
                    consultation_participation_attributes: {
                      id: participation.id,
                      consultation_response_form_attributes: {
                        id: response_form.id,
                        _destroy: "1",
                      },
                    },
                  } }

    refute_select ".errors"
    consultation.reload
    assert_not_nil consultation.consultation_participation.consultation_response_form
  end

  view_test "updating should respect the attachment_action for response forms to keep it" do
    two_pages_pdf = upload_fixture("two-pages.pdf")
    greenpaper_pdf = upload_fixture("greenpaper.pdf")

    response_form = create(:consultation_response_form, file: two_pages_pdf)
    participation = create(:consultation_participation, consultation_response_form: response_form)
    consultation = create(:consultation, consultation_participation: participation)

    put :update,
        params: { id: consultation,
                  edition: {
                    consultation_participation_attributes: {
                      id: participation.id,
                      consultation_response_form_attributes: {
                        id: response_form.id,
                        attachment_action: "keep",
                        _destroy: "1",
                        consultation_response_form_data_attributes: {
                          id: response_form.consultation_response_form_data.id,
                          file: greenpaper_pdf,
                        },
                      },
                    },
                  } }

    refute_select ".errors"
    consultation.reload
    assert_not_nil consultation.consultation_participation.consultation_response_form
    assert_equal "two-pages.pdf", consultation.consultation_participation.consultation_response_form.consultation_response_form_data.carrierwave_file
  end

  view_test "updating should respect the attachment_action for response forms to remove it" do
    AssetManagerDeleteAssetWorker.stubs(:perform_async)

    response_form = create(:consultation_response_form)
    participation = create(:consultation_participation, consultation_response_form: response_form)
    consultation = create(:consultation, consultation_participation: participation)

    put :update,
        params: { id: consultation,
                  edition: {
                    consultation_participation_attributes: {
                      id: participation.id,
                      consultation_response_form_attributes: {
                        id: response_form.id,
                        attachment_action: "remove",
                      },
                    },
                  } }

    refute_select ".errors"
    consultation.reload
    assert_nil consultation.consultation_participation.consultation_response_form
    assert_raise(ActiveRecord::RecordNotFound) do
      response_form.consultation_response_form_data.reload
    end
    assert_raise(ActiveRecord::RecordNotFound) do
      response_form.reload
    end
  end

  view_test "updating should respect the attachment_action for response forms to replace it" do
    Services.asset_manager.stubs(:whitehall_asset).returns("id" => "http://asset-manager/assets/asset-id")
    Services.asset_manager.stubs(:delete_asset)

    two_pages_pdf = upload_fixture("two-pages.pdf")
    greenpaper_pdf = upload_fixture("greenpaper.pdf")

    response_form = create(:consultation_response_form, file: two_pages_pdf)
    participation = create(:consultation_participation, consultation_response_form: response_form)
    consultation = create(:consultation, consultation_participation: participation)

    put :update,
        params: { id: consultation,
                  edition: {
                    consultation_participation_attributes: {
                      id: participation.id,
                      consultation_response_form_attributes: {
                        id: response_form.id,
                        attachment_action: "replace",
                        _destroy: "1",
                        consultation_response_form_data_attributes: {
                          id: response_form.consultation_response_form_data.id,
                          file: greenpaper_pdf,
                        },
                      },
                    },
                  } }

    refute_select ".errors"
    consultation.reload
    assert_not_nil consultation.consultation_participation.consultation_response_form
    assert_equal "greenpaper.pdf", consultation.consultation_participation.consultation_response_form.consultation_response_form_data.carrierwave_file
  end

private

  def controller_attributes_for(edition_type, attributes = {})
    super.except(:alternative_format_provider).reverse_merge(
      alternative_format_provider_id: create(:alternative_format_provider).id,
    )
  end
end
