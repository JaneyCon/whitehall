require "test_helper"

class PaginatedRemarksTest < ActiveSupport::TestCase
  setup do
    @per_page = 3

    @document = create(:document)
    edition = create(:published_edition, document: @document)
    3.times do
      create(:editorial_remark, edition: edition)
      Timecop.travel 1.day.from_now
    end
    @newest_remark = create(:editorial_remark, edition: edition)
  end

  test "#initialize query contains most recent versions first" do
    remarks = Document::PaginatedRemarks.new(@document, 1)
    assert_equal remarks.query.first.id, @newest_remark.id
  end

  test "#initialize performs queries with pagination" do
    mock_pagination do
      expected_pages = 2
      (1..expected_pages).each do |page|
        remarks = Document::PaginatedRemarks.new(@document, page)
        assert remarks.query.count <= @per_page
      end
    end
  end

  def mock_pagination(&block)
    Document::PaginatedRemarks.stub_const(:PER_PAGE, @per_page, &block)
  end
end
