# frozen_string_literal: true

class ErrorSummaryComponent < ViewComponent::Base
  include Admin::AnalyticsHelper

  attr_reader :object, :class_name

  def initialize(object:, class_name: nil)
    @object = object
    @class_name = class_name
  end

  def render?
    object.errors.present?
  end

private

  def construct_class_name
    @construct_class_name ||= class_name.presence || object.class.name.demodulize.underscore.humanize.downcase
  end

  def errors
    object.errors.map { |error|
      tag.li(
        link_for_error(error),
        data: track_analytics_data("form-error", analytics_action, error.full_message),
        class: "gem-c-error-summary__list-item",
      )
    }
    .join("")
    .html_safe
  end

  def analytics_action
    @analytics_action ||= "#{construct_class_name}-error"
  end

  def link_for_error(error)
    tag.a(
      error.full_message,
      href: "##{object.class.to_s.underscore}_#{error.attribute}",
      class: "govuk-link",
    )
  end
end
