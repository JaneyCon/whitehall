module Admin::AuditTrailHelper
  def describe_audit_trail_entry(entry)
    actor = entry.actor
    html = if entry.respond_to?(:message)
             tag.span(class: "body") do
               entry.message
             end
           else
             tag.span(entry.action.capitalize, class: "action") + " by" # rubocop:disable Style/StringConcatenation
           end
    html << " ".html_safe
    html << if actor
              tag.span(class: "actor") { linked_author(actor) }
            else
              "User (removed)"
            end
    html << " ".html_safe
    html << absolute_time(entry.created_at, class: "created_at")
  end

  def paginated_audit_trail_url(page)
    url_for(
      params.to_unsafe_hash
            .merge(controller: "admin/edition_audit_trail", action: "index", page: (page <= 1 ? nil : page))
            .symbolize_keys,
    )
  end

  def render_editorial_remarks(remarks, edition)
    previous_state = nil
    groups = remarks.query.reduce([]) do |memo, remark|
      current_state = if remark.edition_id > edition.id
                        :newer
                      elsif remark.edition_id < edition.id
                        :previous
                      else
                        :current
                      end
      memo << { heading_type: current_state, remarks: [] } if current_state != previous_state
      memo.last[:remarks] << remark
    end
    rendered_groups = groups.map { |g| render_editorial_remarks_list(g[:remarks], g[:heading_type]) }
    safe_join(rendered_groups)
  end

  def render_editorial_remarks_list(remarks, heading_type)
    out = ""
    out << case heading_type
           when :newer then tag.h2("On newer editions", class: "add-top-margin")
           when :previous then tag.h2("On previous editions", class: "add-top-margin")
           when :current then tag.h2("On this edition", class: "add-top-margin")
           end

    remark_items = remarks.map { |r| render(partial: "admin/editions/remark_entry", locals: { remark: r }) }
    out << tag.ul(class: "list-unstyled") { safe_join(remark_items) }
    out.html_safe
  end

  # def render_editorial_remarks(remarks, edition)
  #   previous_state = nil
  #   out = ""
  #   list = ""
  #   remarks.query.each do |remark|
  #     current_state = if remark.edition_id > edition.id
  #                       :newer
  #                     elsif remark.edition_id < edition.id
  #                       :previous
  #                     else
  #                       :current
  #                     end

  #     if current_state != previous_state
  #       out << tag.ul(class: "list-unstyled") { list.html_safe } unless list.empty?
  #       list = ""
  #       out << case current_state
  #              when :newer then tag.h2("On newer editions", class: "add-top-margin")
  #              when :previous then tag.h2("On previous editions", class: "add-top-margin")
  #              when :current then tag.h2("On this edition", class: "add-top-margin")
  #              end
  #     end

  #     list << render(partial: "admin/editions/remark_entry", locals: { remark: remark })
  #     previous_state = current_state
  #   end
  #   out << tag.ul(class: "list-unstyled") { list.html_safe }
  #   out.html_safe
  # end
end
