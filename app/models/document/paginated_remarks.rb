class Document::PaginatedRemarks
  PER_PAGE = 30

  attr_reader :document, :query

  delegate :total_count, to: :query

  def initialize(document, page)
    @document = document
    @query = document.editorial_remarks
                     .includes(:author)
                     .order(created_at: :desc, id: :desc)
                     .page(page)
                     .per(PER_PAGE)
  end

  def entries
    query.to_a
  end
end
