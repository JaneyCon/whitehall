require "test_helper"

class ErrorSummaryComponentTest < ViewComponent::TestCase
  setup do
    @object_with_no_errors = ErrorSummaryTestObject.new("title", Time.zone.today)
    @object_with_errors = ErrorSummaryTestObject.new(nil, nil)
    @object_with_errors.validate
  end

  test "does not render if there are no errors on the object passed in" do
    render_inline(ErrorSummaryComponent.new(object: @object_with_no_errors))
    assert_empty page.text
  end

  test "renders heading using `class_name` if one is passed in" do
    render_inline(ErrorSummaryComponent.new(object: @object_with_errors, class_name: "attachment"))
    assert_selector "h2", text: "To save the attachment please fix the following issues:"
  end

  test "uses the object to construct a heading if a class name is not passed in" do
    render_inline(ErrorSummaryComponent.new(object: @object_with_errors))
    assert_selector "h2", text: "To save the error summary test object please fix the following issues:"
  end

  test "constructs a list of links which link to an id based on the objects class and attribute of the error" do
    render_inline(ErrorSummaryComponent.new(object: @object_with_errors))

    first_link = page.all("li")[0].find("a")
    second_link = page.all("li")[1].find("a")
    third_link = page.all("li")[2].find("a")

    assert_equal page.all("li").count, 3
    assert_equal page.all("li a").count, 3
    assert_equal first_link.text, "Title can't be blank"
    assert_equal first_link[:href], "#error_summary_test_object_title"
    assert_equal second_link.text, "Date can't be blank"
    assert_equal second_link[:href], "#error_summary_test_object_date"
    assert_equal third_link.text, "Date is invalid"
    assert_equal third_link[:href], "#error_summary_test_object_date"
  end

  test "constructs data modules for tracking analytics based on the class name and error message" do
    render_inline(ErrorSummaryComponent.new(object: @object_with_errors))

    first_list = page.all("li")[0]
    second_list = page.all("li")[1]
    third_list = page.all("li")[2]

    assert_equal first_list["data-module"], "auto-track-event"
    assert_equal first_list["data-track-category"], "form-error"
    assert_equal first_list["data-track-action"], "error summary test object-error"
    assert_equal first_list["data-track-label"], "Title can't be blank"
    assert_equal second_list["data-module"], "auto-track-event"
    assert_equal second_list["data-track-category"], "form-error"
    assert_equal second_list["data-track-action"], "error summary test object-error"
    assert_equal second_list["data-track-label"], "Date can't be blank"
    assert_equal third_list["data-module"], "auto-track-event"
    assert_equal third_list["data-track-category"], "form-error"
    assert_equal third_list["data-track-action"], "error summary test object-error"
    assert_equal third_list["data-track-label"], "Date is invalid"
  end
end

class ErrorSummaryTestObject
  include ActiveModel::Model
  attr_accessor :title, :date

  validates :title, :date, presence: true
  validate :date_is_a_date

  def initialize(title, date)
    @title = title
    @date = date
  end

  def date_is_a_date
    errors.add(:date, :invalid) unless date.is_a?(Date)
  end
end
