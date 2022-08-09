require "test_helper"

class Admin::AuditTrailHelperTest < ActionView::TestCase
  setup do
    document = create(:document)
    first_edition = create(:published_edition, document: document)
    create(:editorial_remark, body: "First edition remark", edition: first_edition)
    second_edition = create(:published_edition, document: document)
    create(:editorial_remark, body: "Second edition remark", edition: second_edition)
    newest_edition = create(:published_edition, document: document)
    create(:editorial_remark, body: "Newest edition remark", edition: newest_edition)

    document_remarks = Document::PaginatedRemarks.new(newest_edition.document, 1)

    @render_newest = Nokogiri::HTML(render_editorial_remarks(document_remarks, newest_edition))
    @render_second = Nokogiri::HTML(render_editorial_remarks(document_remarks, second_edition))
    @render_first = Nokogiri::HTML(render_editorial_remarks(document_remarks, first_edition))
  end

  test "#render_editorial_remarks returns the correct h2 tags" do
    assert_select @render_newest, "h2", 2
    assert_select @render_newest, "h2", { text: "On this edition", text: "On previous editions" } # rubocop:disable Lint/DuplicateHashKey
    refute_select @render_newest, "h2", text: "On newer editions"

    assert_select @render_second, "h2", 3
    assert_select @render_second, "h2", { text: "On newer editions", text: "On this edition", text: "On previous editions" } # rubocop:disable Lint/DuplicateHashKey

    assert_select @render_first, "h2", 2
    assert_select @render_first, "h2", { text: "On newer editions", text: "On this edition" } # rubocop:disable Lint/DuplicateHashKey
    refute_select @render_first, "h2", text: "On previous editions"
  end

  test "#render_editorial_remarks groups remarks by newer/current/previous" do
    assert_select @render_newest, "ul", 2 do |ul_tags|
      ul_tags.each_with_index do |ul_tag, index|
        if index.zero?
          assert_select ul_tag, "li", 1
        else
          assert_select ul_tag, "li", 2
          assert_select ul_tag, "span", { text: "First edition remark", text: "Second edition remark" } # rubocop:disable Lint/DuplicateHashKey
          refute_select ul_tag, "span", text: "Newest edition remark"
        end
      end
    end

    assert_select @render_second, "ul", 3 do |ul_tags|
      ul_tags.each_with_index do |ul_tag, _index|
        assert_select ul_tag, "li", 1
      end
    end

    assert_select @render_first, "ul", 2 do |ul_tags|
      ul_tags.each_with_index do |ul_tag, index|
        if index.zero?
          assert_select ul_tag, "li", 2
          assert_select ul_tag, "span", { text: "Newest edition remark", text: "Second edition remark" } # rubocop:disable Lint/DuplicateHashKey
          refute_select ul_tag, "span", text: "First edition remark"
        else
          assert_select ul_tag, "li", 1
        end
      end
    end
  end
end
