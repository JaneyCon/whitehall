DocumentFilterPresenter = Struct.new(:filter, :context, :document_decorator) do # rubocop:disable Lint/StructNewOverride
  extend Whitehall::Decorators::DelegateInstanceMethodsOf
  delegate_instance_methods_of Whitehall::DocumentFilter::Filterer, to: :filter

  def as_json(options = nil)
    as_hash(options)
  end

  def as_hash(_options = nil)
    data = {
      count: documents.count,
      current_page: documents.current_page,
      total_pages: documents.total_pages,
      total_count: documents.total_count,
      results: documents.each_with_index.map { |d, i| { result: d.as_hash, index: i + 1 } },
      results_any?: documents.any?,
      result_type:,
      no_results_title: context.t("document_filters.no_results.title"),
      no_results_description: context.t("document_filters.no_results.description"),
      no_results_tna_heading: context.t("document_filters.no_results.tna_heading"),
      no_results_tna_link: context.t("document_filters.no_results.tna_link_html"),
      category: result_type.capitalize,
    }
    if !documents.last_page? || !documents.first_page?
      data[:more_pages?] = true
    end
    unless documents.last_page?
      data[:next_page?] = true
      data[:next_page] = documents.current_page + 1
      data[:next_page_url] = url(page: documents.current_page + 1)
      data[:next_page_web_url] = url(page: documents.current_page + 1, format: nil)
    end
    unless documents.first_page?
      data[:prev_page?] = true
      data[:prev_page] = documents.current_page - 1
      data[:prev_page_url] = url(page: documents.current_page - 1)
      data[:prev_page_web_url] = url(page: documents.current_page - 1, format: nil)
    end
    data
  end

  def url(override_params)
    context.url_for(context.params.permit!.merge(override_params).merge("_" => nil))
  end

  def date_from
    from_date ? from_date.to_fs(:uk_short) : nil
  end

  def date_to
    to_date ? to_date.to_fs(:uk_short) : nil
  end

  def documents
    if document_decorator
      Whitehall::Decorators::CollectionDecorator.new(
        filter.documents, document_decorator, context
      )
    else
      filter.documents
    end
  end

  def result_type
    "document"
  end

  def filtering_command_and_act_papers?
    selected_official_document_status == "command_and_act_papers"
  end

  def filtering_command_papers_only?
    selected_official_document_status == "command_papers_only"
  end

  def filtering_act_papers_only?
    selected_official_document_status == "act_papers_only"
  end
end
