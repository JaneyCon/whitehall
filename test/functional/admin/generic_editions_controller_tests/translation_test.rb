require "test_helper"

class Admin::GenericEditionsController::TranslationTest < ActionController::TestCase
  include TaxonomyHelper
  tests Admin::GenericEditionsController

  setup do
    GenericEdition.translatable = true
    login_as :writer
  end

  teardown do
    GenericEdition.translatable = false
  end

  view_test "show links to new translation page when the edition is editable" do
    edition = create(:draft_edition, title: "english-title", summary: "english-summary", body: "english-body")
    stub_publishing_api_expanded_links_with_taxons(edition.content_id, [])

    get :show, params: { id: edition }

    assert_select "a[href='#{new_admin_edition_translation_path(edition)}']", text: "Add translation"
  end

  view_test "show omits new translation link unless the edition is editable" do
    edition = create(:published_edition)
    stub_publishing_api_expanded_links_with_taxons(edition.content_id, [])
    assert_not edition.editable?

    get :show, params: { id: edition }

    assert_select "a[href='#{new_admin_edition_translation_path(edition)}']", text: "Add translation", count: 0
  end

  view_test "show displays a link to edit an existing translation" do
    edition = create(:draft_edition, title: "english-title", summary: "english-summary", body: "english-body")
    stub_publishing_api_expanded_links_with_taxons(edition.content_id, [])
    with_locale(:fr) { edition.update!(title: "french-title", summary: "french-summary", body: "french-body") }

    get :show, params: { id: edition }

    assert_select "a[href='#{edit_admin_edition_translation_path(edition, 'fr')}']", text: "Edit"
  end

  view_test "show displays a link to delete an existing translation" do
    edition = create(:draft_edition, title: "english-title", summary: "english-summary", body: "english-body")
    stub_publishing_api_expanded_links_with_taxons(edition.content_id, [])
    with_locale(:fr) { edition.update!(title: "french-title", summary: "french-summary", body: "french-body") }

    get :show, params: { id: edition }

    assert_select "form[action=?]", admin_edition_translation_path(edition, "fr") do
      assert_select "input[type='submit'][value=?]", "Delete"
    end
  end

  view_test "show displays the language of the translation on published editions" do
    edition = build(:published_edition, title: "english-title", summary: "english-summary", body: "english-body")
    with_locale(:fr) do
      edition.attributes = { title: "french-title", summary: "french-summary", body: "french-body" }
    end
    edition.save!

    stub_publishing_api_expanded_links_with_taxons(edition.content_id, [])

    get :show, params: { id: edition }

    assert_select "#translations" do
      assert_select "td", text: "French"
    end
  end

  view_test "show omits the link to edit an existing translation unless the edition is editable" do
    edition = create(:draft_edition, title: "english-title", summary: "english-summary", body: "english-body")
    stub_publishing_api_expanded_links_with_taxons(edition.content_id, [])
    with_locale(:fr) { edition.update!(title: "french-title", summary: "french-summary", body: "french-body") }
    force_publish(edition)

    get :show, params: { id: edition }

    assert_select "#translations a[href='#{edit_admin_edition_translation_path(edition, 'fr')}']", count: 0
  end

  view_test "show omits the link to delete an existing translation unless the edition is deletable" do
    edition = create(:draft_edition, title: "english-title", summary: "english-summary", body: "english-body")
    stub_publishing_api_expanded_links_with_taxons(edition.content_id, [])
    with_locale(:fr) { edition.update!(title: "french-title", summary: "french-summary", body: "french-body") }
    force_publish(edition)

    get :show, params: { id: edition }

    assert_select "#translations form[action=?]", admin_edition_translation_path(edition, "fr"), count: 0
  end

  view_test "show displays all non-english translations" do
    edition = create(:draft_edition, title: "english-title", summary: "english-summary", body: "english-body-in-govspeak")
    stub_publishing_api_expanded_links_with_taxons(edition.content_id, [])
    with_locale(:fr) { edition.update!(title: "french-title", summary: "french-summary", body: "french-body-in-govspeak") }

    transformation = {
      "english-body-in-govspeak" => "english-body-in-html",
      "french-body-in-govspeak" => "french-body-in-html",
    }
    govspeak_transformation_fixture(transformation) do
      get :show, params: { id: edition }
    end

    assert_select "#translations" do
      refute_select "td", text: "english-title"
      assert_select "td", text: "french-title"
    end
  end
end
