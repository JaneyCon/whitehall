require "test_helper"

class Admin::FactCheckRequestsControllerTest < ActionController::TestCase
  should_be_an_admin_controller

  setup do
    login_as_admin
  end

  view_test "#index should render previous fact checking requests in the correct order" do
    edition = create(:publication)
    completed_fact_check = create(:fact_check_request, edition:, comments: "comment")
    pending_fact_check = create(:fact_check_request, edition:, comments: nil)

    get :index, params: { edition_id: edition }

    assert_select ".responses .from", text: completed_fact_check.email_address
    assert_select ".pending .from", text: pending_fact_check.email_address
  end

  view_test "should render the content using govspeak markup" do
    edition = create(:edition, body: "body-in-govspeak")
    fact_check_request = create(:fact_check_request, edition:, comments: "comment")
    govspeak_transformation_fixture "body-in-govspeak" => "body-in-html" do
      get :show, params: { id: fact_check_request }
    end

    assert_select ".body", text: "body-in-html"
  end

  view_test "should not display the edition if it has been deleted" do
    edition = create(:deleted_edition, title: "deleted-publication-title", body: "deleted-publication-body")
    fact_check_request = create(:fact_check_request, edition:)

    get :show, params: { id: fact_check_request }

    assert_select ".fact_check_request .apology", text: "We’re sorry, but this document is no longer available for fact checking."
    refute_select ".title", text: "deleted-publication-title"
    refute_select ".body", text: "deleted-publication-body"
  end

  test "users with a valid.to_param should be able to access the publication" do
    fact_check_request = create(:fact_check_request)

    get :edit, params: { id: fact_check_request }

    assert_response :success
    assert_template "admin/fact_check_requests/edit"
  end

  test "users with invalid token should not be able to access the publication" do
    get :edit, params: { id: "invalid-token" }

    assert_response :not_found
  end

  view_test "it should not be possible to fact check a deleted edition" do
    edition = create(:deleted_edition, title: "deleted-publication-title", body: "deleted-publication-body")
    fact_check_request = create(:fact_check_request, edition:)

    get :edit, params: { id: fact_check_request }

    assert_select ".fact_check_request .apology", text: "We’re sorry, but this document is no longer available for fact checking."
    refute_select ".document .title", text: "deleted-publication-title"
    refute_select ".document .body", text: "deleted-publication-body"
  end

  view_test "turn govspeak into nice markup when editing" do
    edition = create(:edition, body: "body-in-govspeak")
    fact_check_request = create(:fact_check_request, edition:)
    govspeak_transformation_fixture "body-in-govspeak" => "body-in-html" do
      get :edit, params: { id: fact_check_request }
    end

    assert_select ".body", text: "body-in-html"
  end

  test "adding comments to a publication" do
    publication = create(:publication)
    fact_check_request = create(:fact_check_request, edition: publication)

    get :edit, params: { id: fact_check_request }

    assert_response :success
  end

  view_test "should display any additional instructions to the fact checker" do
    fact_check_request = create(:fact_check_request, instructions: "Please concentrate on the content")

    get :edit, params: { id: fact_check_request }

    assert_select "#fact_check_request_instructions", text: /Please concentrate on the content/
  end

  view_test "should not display the extra instructions section" do
    fact_check_request = create(:fact_check_request, instructions: "")

    get :edit, params: { id: fact_check_request }

    refute_select "#fact_check_request_instructions"
  end

  test "save the fact checkers comment" do
    fact_check_request = create(:fact_check_request)
    attributes = attributes_for(:fact_check_request, comments: "looks fine to me")

    put :update, params: { id: fact_check_request, fact_check_request: attributes }

    fact_check_request.reload
    assert_equal "looks fine to me", fact_check_request.comments
  end

  test "notify a requestor with an email address that the fact checker has added a comment" do
    requestor = create(:fact_check_requestor, email: "fact-check-requestor@example.com")
    fact_check_request = create(:fact_check_request, requestor:)
    attributes = attributes_for(:fact_check_request, comments: "looks fine to me")
    ActionMailer::Base.deliveries.clear

    put :update, params: { id: fact_check_request, fact_check_request: attributes }

    assert_equal 1, ActionMailer::Base.deliveries.length
  end

  test "raise an error if an email cannot be sent via notify" do
    raises_exception = lambda { |_request, _params|
      response = MiniTest::Mock.new
      response.expect :code, 400
      response.expect :body, "Can't send to this recipient using a team-only API key"
      raise Notifications::Client::BadRequestError, response
    }

    MailNotifications.stub(:fact_check_response, raises_exception) do
      requestor = create(:fact_check_requestor, email: "fact-check-requestor@example.com")
      fact_check_request = create(:fact_check_request, requestor:)
      attributes = attributes_for(:fact_check_request, comments: "looks fine to me")
      ActionMailer::Base.deliveries.clear

      put :update, params: { id: fact_check_request, fact_check_request: attributes }
      assert_equal response.body, "Error: One or more recipients not in GOV.UK Notify team (code: 400)"
      assert_equal response.code, "400"

      assert_equal 0, ActionMailer::Base.deliveries.length
    end
  end

  test "do not notify a requestor without an email address that the fact checker has added a comment" do
    requestor = create(:fact_check_requestor, email: nil)
    fact_check_request = create(:fact_check_request, requestor:)
    attributes = attributes_for(:fact_check_request, comments: "looks fine to me")
    ActionMailer::Base.deliveries.clear

    put :update, params: { id: fact_check_request, fact_check_request: attributes }

    assert_equal 0, ActionMailer::Base.deliveries.length
  end

  test "redirect to the show page when a fact check has been completed" do
    fact_check_request = create(:fact_check_request)
    attributes = attributes_for(:fact_check_request, comments: "looks fine to me")

    put :update, params: { id: fact_check_request, fact_check_request: attributes }

    assert_redirected_to admin_fact_check_request_path(fact_check_request)
  end

  view_test "display an apology if comments are submitted for a deleted edition" do
    edition = create(:deleted_edition)
    fact_check_request = create(:fact_check_request, edition:)
    attributes = attributes_for(:fact_check_request, comments: "looks fine to me")

    put :update, params: { id: fact_check_request, fact_check_request: attributes }

    assert_select ".fact_check_request .apology", text: "We’re sorry, but this document is no longer available for fact checking."
  end
end

class Admin::CreatingFactCheckRequestsControllerTest < ActionController::TestCase
  tests Admin::FactCheckRequestsController

  setup do
    @attributes = attributes_for(:fact_check_request)
    @edition = create(:draft_publication)
    @requestor = login_as(:writer)
    ActionMailer::Base.deliveries.clear
  end

  teardown do
    request.host = "test.host"
    request.env["HTTPS"] = nil
  end

  test "should create a fact check request" do
    @attributes[:email_address] = "fact-checker@example.com"
    post :create, params: { edition_id: @edition.id, fact_check_request: @attributes }

    assert fact_check_request = @edition.fact_check_requests.last
    assert_equal "fact-checker@example.com", fact_check_request.email_address
    assert_equal @requestor, fact_check_request.requestor
  end

  test "should prevent creation of a fact check request if edition is not accessible to the current user" do
    protected_edition = create(:draft_publication, :access_limited)
    post :create, params: { edition_id: protected_edition.id, fact_check_request: @attributes }

    assert_response :forbidden
  end

  test "should send an email when a fact check has been requested" do
    post :create, params: { edition_id: @edition.id, fact_check_request: @attributes }

    assert_equal 1, ActionMailer::Base.deliveries.length
  end

  test "uses host from request in email urls" do
    request.host = "whitehall.example.com"
    post :create, params: { edition_id: @edition.id, fact_check_request: @attributes }

    assert_last_email_body_contains("http://whitehall.example.com/")
  end

  test "uses protocol from request in email urls" do
    request.env["HTTPS"] = "on"
    request.host = "whitehall.example.com"
    post :create, params: { edition_id: @edition.id, fact_check_request: @attributes }

    assert_last_email_body_contains("https://whitehall.example.com/")
  end

  test "uses port from request in email urls" do
    request.host = "whitehall.example.com:8182"
    post :create, params: { edition_id: @edition.id, fact_check_request: @attributes }

    assert_last_email_body_contains("http://whitehall.example.com:8182/")
  end

  test "display an informational message when a fact check has been requested" do
    post :create, params: { edition_id: @edition.id, fact_check_request: @attributes }

    assert_equal "The document has been sent to fact-checker@example.com", flash[:notice]
  end

  test "redirect back to the edition preview when a fact check has been requested" do
    post :create, params: { edition_id: @edition.id, fact_check_request: @attributes }

    assert_redirected_to admin_publication_path(@edition)
  end

  test "redirect back to the fact check index page a fact check has been requested and the user has the `View move tabs to endpoints` permission" do
    @requestor.permissions << "View move tabs to endpoints"
    post :create, params: { edition_id: @edition.id, fact_check_request: @attributes }

    assert_redirected_to admin_edition_fact_check_requests_path(@edition)
  end

  test "should not send an email if the fact checker's email address is missing" do
    @attributes[:email_address] = ""
    post :create, params: { edition_id: @edition.id, fact_check_request: @attributes }

    assert_equal 0, ActionMailer::Base.deliveries.length
  end

  test "should display a warning if the fact checker's email address is missing" do
    @attributes[:email_address] = ""
    post :create, params: { edition_id: @edition.id, fact_check_request: @attributes }

    assert_equal "There was a problem: Email address can't be blank", flash[:alert]
  end

  test "redirect back to the edition preview if the fact checker's email address is missing" do
    @attributes[:email_address] = ""
    post :create, params: { edition_id: @edition.id, fact_check_request: @attributes }

    assert_redirected_to admin_publication_path(@edition)
  end

  test "redirect back to the fact checking new view if the fact checker's email address is missing and the user has the `View move tabs to endpoints` permission" do
    @requestor.permissions << "View move tabs to endpoints"
    @attributes[:email_address] = ""
    post :create, params: { edition_id: @edition.id, fact_check_request: @attributes }

    assert_redirected_to new_admin_edition_fact_check_request_path(@edition)
  end

  test "should reject invalid email addresses" do
    @attributes[:email_address] = "not-an-email"
    post :create, params: { edition_id: @edition.id, fact_check_request: @attributes }

    assert_match "There was a problem: Email address does not appear to be a valid e-mail address", flash[:alert]
  end

  view_test "should display an apology if requesting a fact check for an edition that has been deleted" do
    edition = create(:deleted_publication)
    post :create, params: { edition_id: edition.id, fact_check_request: @attributes }

    assert_select ".fact_check_request .apology", text: "We’re sorry, but this document is no longer available for fact checking."
  end

private

  def assert_last_email_body_contains(text)
    assert_match Regexp.new(Regexp.escape(text)), ActionMailer::Base.deliveries.last.body.to_s
  end
end
