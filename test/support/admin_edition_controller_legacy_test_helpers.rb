require_relative "taxonomy_helper"

module AdminEditionControllerLegacyTestHelpers
  extend ActiveSupport::Concern
  include ActionMailer::TestHelper
  include TaxonomyHelper

  module ClassMethods
    def legacy_should_have_summary(edition_type)
      edition_class = class_for(edition_type)

      test "create should create a new #{edition_type} with summary" do
        attributes = controller_attributes_for(edition_type)

        post :create,
             params: {
               edition: attributes.merge(
                 summary: "my summary",
               ),
             }

        created_edition = edition_class.last
        assert_equal "my summary", created_edition.summary
      end

      test "update should save modified news article summary" do
        edition = create(edition_type) # rubocop:disable Rails/SaveBang

        put :update,
            params: {
              id: edition,
              edition: {
                summary: "new-summary",
              },
            }

        edition.reload
        assert_equal "new-summary", edition.summary
      end
    end

    def legacy_should_allow_creating_of(edition_type)
      edition_class = class_for(edition_type)

      view_test "new displays edition form" do
        get :new

        admin_editions_path = send("admin_#{edition_type.to_s.tableize}_path")
        assert_select "form#new_edition[action='#{admin_editions_path}']" do
          assert_select "input[name='edition[title]'][type='text']"
          assert_select "textarea[name='edition[summary]']"
          assert_select "textarea[name='edition[body]']"
          assert_select "input[type='submit']"
        end
      end

      view_test "new form has previewable body" do
        get :new
        assert_select "textarea[name='edition[body]'].previewable"
      end

      view_test "new form has cancel link which takes the user to the list of drafts" do
        get :new
        assert_select "a[href=?]", admin_editions_path, text: /cancel/i
      end

      test "create should create a new edition" do
        attributes = controller_attributes_for(edition_type)

        post :create,
             params: {
               edition: attributes,
             }

        edition = edition_class.last
        assert_equal attributes[:title], edition.title
        assert_equal attributes[:body], edition.body
      end

      test "create should take the writer to the topic tagging page" do
        organisation = create(:organisation)

        attributes = controller_attributes_for(edition_type).merge(
          publication_type_id: PublicationType::Guidance.id,
          lead_organisation_ids: [organisation.id],
        )

        post :create,
             params: {
               edition: attributes,
             }

        edition = edition_class.last

        assert_redirected_to edit_admin_edition_tags_path(edition.id)
        assert_equal "The document has been saved", flash[:notice]
      end

      test "create should email content second line if the user is monitored" do
        Edition.any_instance.stubs(:should_alert_for?).returns(true)

        assert_emails 1 do
          post :create,
               params: {
                 edition: controller_attributes_for(edition_type),
               }
        end
      end

      test "create should not email content second line if the user is not monitored" do
        Edition.any_instance.stubs(:should_alert_for?).returns(false)

        assert_no_emails do
          post :create,
               params: {
                 edition: controller_attributes_for(edition_type),
               }
        end
      end

      test "create with invalid data should leave the writer in the document editor" do
        attributes = controller_attributes_for(edition_type)
        post :create,
             params: {
               edition: attributes.merge(title: ""),
             }

        assert_equal attributes[:body], assigns(:edition).body, "the valid data should not have been lost"
        assert_template "editions/new_legacy"
      end

      view_test "create with invalid data should indicate there was an error" do
        attributes = controller_attributes_for(edition_type)
        post :create,
             params: {
               edition: attributes.merge(title: ""),
             }

        assert_select ".field_with_errors input[name='edition[title]']"
        assert_equal attributes[:body], assigns(:edition).body, "the valid data should not have been lost"
        assert_equal "There are some problems with the document", flash.now[:alert]
      end

      test "removes blank space from titles for new editions" do
        attributes = controller_attributes_for(edition_type)

        post :create,
             params: {
               edition: attributes.merge(title: "   my title   "),
             }

        edition = edition_class.last
        assert_equal "my title", edition.title
      end
    end

    def legacy_should_allow_editing_of(edition_type)
      legacy_should_report_editing_conflicts_of(edition_type)

      view_test "edit displays edition form" do
        edition = create(edition_type) # rubocop:disable Rails/SaveBang

        get :edit, params: { id: edition }

        admin_edition_path = send("admin_#{edition_type}_path", edition)
        assert_select "form#edit_edition[action='#{admin_edition_path}']" do
          assert_select "input[name='edition[title]'][type='text']"
          assert_select "textarea[name='edition[body]']"
          assert_select "input[type='submit']"
        end
      end

      view_test "edit form has previewable body" do
        edition = create(edition_type) # rubocop:disable Rails/SaveBang

        get :edit, params: { id: edition }

        assert_select "textarea[name='edition[body]'].previewable"
      end

      view_test "edit form has cancel link which takes the user back to edition" do
        draft_edition = create("draft_#{edition_type}")

        get :edit, params: { id: draft_edition }

        admin_edition_path = send("admin_#{edition_type}_path", draft_edition)
        assert_select "a[href=?]", admin_edition_path, text: /cancel/i
      end

      test "update should save modified edition attributes" do
        edition = create(edition_type) # rubocop:disable Rails/SaveBang

        put :update,
            params: {
              id: edition,
              edition: {
                title: "new-title",
                body: "new-body",
              },
            }

        edition.reload
        assert_equal "new-title", edition.title
        assert_equal "new-body", edition.body
      end

      test "update should take the writer to the topic tagging page after updating" do
        edition = create(edition_type) # rubocop:disable Rails/SaveBang

        organisation = create(:organisation)

        put :update,
            params: {
              id: edition,
              edition: {
                lead_organisation_ids: [organisation.id],
              },
            }

        assert_redirected_to edit_admin_edition_tags_path(edition.id)
        assert_equal "The document has been saved", flash[:notice]
      end

      test "update records the user who changed the edition" do
        edition = create(edition_type) # rubocop:disable Rails/SaveBang

        put :update,
            params: {
              id: edition,
              edition: {
                title: "new-title",
                body: "new-body",
              },
            }

        assert_equal current_user, edition.edition_authors.reload.last.user
      end

      test "update with invalid data should not save the edition" do
        edition = create(edition_type, title: "A Title")

        put :update,
            params: {
              id: edition,
              edition: {
                title: "",
              },
            }

        assert_equal "A Title", edition.reload.title
        assert_template "editions/edit_legacy"
        assert_equal "There are some problems with the document", flash.now[:alert]
      end

      test "update with a stale edition should render edit page with conflicting edition" do
        edition = create("draft_#{edition_type}")
        lock_version = edition.lock_version
        edition.touch

        put :update,
            params: {
              id: edition,
              edition: {
                lock_version:,
              },
            }

        assert_template "edit_legacy"
        conflicting_edition = edition.reload
        assert_equal conflicting_edition, assigns(:conflicting_edition)
        assert_equal conflicting_edition.lock_version, assigns(:edition).lock_version
        assert_equal %(This document has been saved since you opened it), flash[:alert]
      end

      test "removes blank space from titles for updated editions" do
        edition = create(edition_type) # rubocop:disable Rails/SaveBang

        put :update,
            params: {
              id: edition,
              edition: {
                title: "   my title    ",
                previously_published: false,
              },
            }

        assert_equal "my title", edition.reload.title
      end
    end

    def legacy_should_send_drafts_to_content_preview_environment_for(edition_type)
      test "updating a draft edition sends the draft to the content preview environment" do
        edition = create("draft_#{edition_type}")

        Whitehall::PublishingApi.expects(:save_draft).with(
          all_of(
            responds_with(:model_name, "CaseStudy"),
            responds_with(:id, edition.id),
          ),
        )

        put :update, params: { id: edition, edition: { title: "updated title" } }
      end

      test "updating a submitted edition sends the draft to the content preview environment" do
        edition = create("submitted_#{edition_type}")

        Whitehall::PublishingApi.expects(:save_draft).with(
          all_of(
            responds_with(:model_name, "CaseStudy"),
            responds_with(:id, edition.id),
          ),
        )

        put :update,
            params: {
              id: edition,
              edition: {
                title: "updated title",
              },
            }
      end

      test "updating a rejected edition sends the draft to the content preview environment" do
        edition = create("rejected_#{edition_type}")

        Whitehall::PublishingApi.expects(:save_draft).with(
          all_of(
            responds_with(:model_name, "CaseStudy"),
            responds_with(:id, edition.id),
          ),
        )

        put :update,
            params: {
              id: edition,
              edition: {
                title: "updated title",
              },
            }
      end

      view_test "reports an error if the updater has an error on create" do
        draft_updater = stub(
          "draft updater",
          can_perform?: false,
          perform!: false,
          failure_reason: "Unable to perform draft update",
        )

        Whitehall.edition_services.stubs(:draft_updater).returns(draft_updater)

        attributes = controller_attributes_for(edition_type)

        assert_difference "Edition.count", 0 do
          post :create,
               params: {
                 edition: attributes.merge(
                   summary: "my summary",
                 ),
               }
        end

        assert_template "editions/new_legacy"
        assert_equal "There are some problems with the document", flash.now[:alert]
        assert_select ".alert", text: /Unable to perform draft update/
      end

      view_test "reports an error if the updater has an error on update" do
        edition = create("draft_#{edition_type}", title: "Original title")

        draft_updater = stub(
          "draft updater",
          can_perform?: false,
          perform!: false,
          failure_reason: "Unable to perform draft update",
        )

        Whitehall.edition_services.stubs(:draft_updater).returns(draft_updater)

        put :update,
            params: {
              id: edition,
              edition: {
                title: "updated title",
              },
            }

        assert_equal "Original title", edition.reload.title
        assert_template "editions/edit_legacy"
        assert_equal "There are some problems with the document", flash.now[:alert]
        assert_select ".alert", text: /Unable to perform draft update/
      end
    end

    def legacy_should_allow_speed_tagging_of(edition_type)
      test "update should convert #{edition_type} to draft when speed tagging" do
        edition = create("imported_#{edition_type}")

        put :update,
            params: {
              id: edition,
              speed_save_convert: 1,
              edition: {
                title: "new-title",
                body: "new-body",
              },
            }

        edition.reload
        assert_equal "draft", edition.state
        assert_redirected_to edit_admin_edition_tags_path(edition.id)
      end
    end

    def legacy_should_allow_attached_images_for(edition_type)
      edition_class = class_for(edition_type)

      view_test "new displays edition image fields" do
        get :new

        assert_select "form#new_edition" do
          assert_select "input[name='edition[images_attributes][0][alt_text]'][type='text']"
          assert_select "textarea[name='edition[images_attributes][0][caption]']"
          assert_select "input[name='edition[images_attributes][0][image_data_attributes][file]'][type='file']"
        end
      end

      test "creating an edition should attach image" do
        image = upload_fixture("minister-of-funk.960x640.jpg", "image/jpg")
        attributes = controller_attributes_for(edition_type)
        attributes[:images_attributes] = {
          "0" => { alt_text: "some-alt-text",
                   caption: "longer-caption-for-image",
                   image_data_attributes: attributes_for(:image_data, file: image) },
        }

        post :create,
             params: {
               edition: attributes,
             }

        assert_response :redirect

        edition = edition_class.last!
        assert_equal 1, edition.images.length
        image = edition.images.first
        assert_equal "some-alt-text", image.alt_text
        assert_equal "longer-caption-for-image", image.caption
      end

      test "creating an edition should result in a single instance of the uploaded image file being cached" do
        image = upload_fixture("minister-of-funk.960x640.jpg", "image/jpg")
        attributes = controller_attributes_for(edition_type)
        attributes[:images_attributes] = {
          "0" => { alt_text: "some-alt-text",
                   image_data_attributes: attributes_for(:image_data, file: image) },
        }

        ImageData.any_instance.expects(:file=).once

        post :create,
             params: {
               edition: attributes,
             }
      end

      view_test "creating an edition with invalid data should still show image fields" do
        post :create,
             params: {
               edition: controller_attributes_for(edition_type, title: ""),
             }

        assert_select "form#new_edition" do
          assert_select "input[name='edition[images_attributes][0][alt_text]'][type='text']"
          assert_select "textarea[name='edition[images_attributes][0][caption]']"
          assert_select "input[name='edition[images_attributes][0][image_data_attributes][file]'][type='file']"
        end
      end

      view_test "creating an edition with invalid data should only allow a single image to be selected for upload" do
        image = upload_fixture("minister-of-funk.960x640.jpg", "image/jpg")
        attributes = controller_attributes_for(edition_type, title: "")
        attributes[:images_attributes] = {
          "0" => { alt_text: "some-alt-text",
                   image_data_attributes: attributes_for(:image_data, file: image) },
        }

        post :create,
             params: {
               edition: attributes,
             }

        assert_select "form#new_edition" do
          assert_select "input[name*='edition[images_attributes]'][type='file']", count: 1
        end
      end

      view_test "creating an edition with invalid data but valid image data should still display the image data" do
        image = upload_fixture("minister-of-funk.960x640.jpg", "image/jpg")
        attributes = controller_attributes_for(edition_type, title: "")
        attributes[:images_attributes] = {
          "0" => { alt_text: "some-alt-text",
                   image_data_attributes: attributes_for(:image_data, file: image) },
        }

        post :create,
             params: {
               edition: attributes,
             }

        assert_select "form#new_edition" do
          assert_select "input[name='edition[images_attributes][0][alt_text]'][type='text'][value='some-alt-text']"
          assert_select "input[name='edition[images_attributes][0][image_data_attributes][file_cache]'][value$='minister-of-funk.960x640.jpg']"
          assert_select ".already_uploaded", text: "minister-of-funk.960x640.jpg already uploaded"
        end
      end

      view_test "creating an edition with invalid data should not show any existing image info" do
        image = upload_fixture("minister-of-funk.960x640.jpg", "image/jpg")
        attributes = controller_attributes_for(edition_type, title: "")
        attributes[:images_attributes] = {
          "0" => { alt_text: "some-alt-text",
                   image_data_attributes: attributes_for(:image_data, file: image) },
        }

        post :create,
             params: {
               edition: attributes,
             }

        refute_select "p.image"
      end

      test "creating an edition with multiple images should attach all files" do
        image_file0 = upload_fixture("minister-of-funk.960x640.jpg", "image/jpg")
        image_file1 = upload_fixture("minister-of-funk.960x640.jpg", "image/jpg")
        attributes = controller_attributes_for(edition_type)
        attributes[:images_attributes] = {
          "0" => { alt_text: "some-alt-text",
                   image_data_attributes: attributes_for(:image_data, file: image_file0) },
          "1" => { alt_text: "more-alt-text",
                   image_data_attributes: attributes_for(:image_data, file: image_file1) },
        }

        post :create,
             params: {
               edition: attributes,
             }

        assert_response :redirect

        edition = edition_class.last!
        assert_equal 2, edition.images.length
        image1 = edition.images.first
        assert_equal "some-alt-text", image1.alt_text
        image2 = edition.images.last
        assert_equal "more-alt-text", image2.alt_text
      end

      view_test "creating an edition with an invalid image should show an error" do
        attributes = controller_attributes_for(edition_type)
        invalid_image = upload_fixture("horrible-image.64x96.jpg", "image/jpg")

        post :create,
             params: {
               edition: attributes.merge(
                 images_attributes: {
                   "0" => { alt_text: "alt-text", image_data_attributes: attributes_for(:image_data, file: invalid_image) },
                 },
               ),
             }

        assert_select ".errors", text: "Images image data file must be 960px wide and 640px tall, but is 64px wide and 96px tall"
      end

      view_test "edit displays edition image fields" do
        image = upload_fixture("minister-of-funk.960x640.jpg", "image/jpg")
        edition = create(edition_type) # rubocop:disable Rails/SaveBang
        create(
          :image,
          alt_text: "blah",
          edition:,
          image_data_attributes: attributes_for(:image_data, file: image),
        )

        get :edit, params: { id: edition }

        assert_select "form#edit_edition" do
          assert_select "input[name='edition[images_attributes][0][alt_text]'][type='text'][value='blah']"
          assert_select ".image" do
            assert_select "img[src$='minister-of-funk.960x640.jpg']"
          end
          assert_select "input[name='edition[images_attributes][1][alt_text]'][type='text']"
          assert_select "textarea[name='edition[images_attributes][1][caption]']"
          assert_select "input[name='edition[images_attributes][1][image_data_attributes][file]'][type='file']"
        end
      end

      test "updating an edition should attach an image" do
        image = upload_fixture("minister-of-funk.960x640.jpg")
        edition = create(edition_type) # rubocop:disable Rails/SaveBang

        put :update,
            params: {
              id: edition,
              edition: {
                images_attributes: {
                  "0" => { alt_text: "alt-text", image_data_attributes: attributes_for(:image_data, file: image) },
                },
              },
            }

        edition.reload
        assert_equal 1, edition.images.length
        image = edition.images.first
        assert_equal "alt-text", image.alt_text
      end

      view_test "updating an edition with image alt text but no file attachment should show a validation error" do
        edition = create(edition_type) # rubocop:disable Rails/SaveBang

        put :update,
            params: {
              id: edition,
              edition: {
                images_attributes: {
                  "0" => {
                    alt_text: "alt-text",
                    image_data_attributes: {
                      file_cache: "",
                    },
                  },
                },
              },
            }

        assert_select ".errors", text: "Images image data file can't be blank"

        edition.reload
        assert_equal 0, edition.images.length
      end

      test "updating an edition with an existing image allows image attributes to be changed" do
        edition = create(edition_type) # rubocop:disable Rails/SaveBang
        image = create(
          :image,
          edition:,
          alt_text: "old-alt-text",
          caption: "old-caption",
          image_data_attributes: attributes_for(:image_data, file: upload_fixture("minister-of-funk.960x640.jpg", "image/jpg")),
        )

        put :update,
            params: {
              id: edition,
              edition: {
                images_attributes: {
                  "0" => {
                    id: image.id,
                    alt_text: "new-alt-text",
                    caption: "new-caption",
                  },
                },
              },
            }

        assert_response :redirect
        image = edition.reload.images.first
        assert_equal "new-alt-text", image.alt_text
        assert_equal "new-caption", image.caption
      end

      test "updating an edition should attach multiple images" do
        edition = create(edition_type) # rubocop:disable Rails/SaveBang
        image_file0 = upload_fixture("minister-of-funk.960x640.jpg", "image/jpg")
        image_file1 = upload_fixture("minister-of-funk.960x640.jpg", "image/jpg")
        attributes = { images_attributes: {
          "0" => { alt_text: "some-alt-text",
                   image_data_attributes: attributes_for(:image_data, file: image_file0) },
          "1" => { alt_text: "more-alt-text",
                   image_data_attributes: attributes_for(:image_data, file: image_file1) },
        } }

        put :update, params: { id: edition, edition: attributes }

        assert_response :redirect

        assert_equal 2, edition.images.length
        image1 = edition.images.first
        assert_equal "some-alt-text", image1.alt_text
        image2 = edition.images.last
        assert_equal "more-alt-text", image2.alt_text
      end

      view_test "updating an edition with invalid data should still allow image to be selected for upload" do
        edition = create(edition_type) # rubocop:disable Rails/SaveBang
        put :update,
            params: {
              id: edition,
              edition: {
                title: "",
              },
            }

        assert_select "form#edit_edition" do
          assert_select "input[name='edition[images_attributes][0][image_data_attributes][file]'][type='file']"
        end
      end

      view_test "updating an edition with invalid data should only allow a single image to be selected for upload" do
        edition = create(edition_type) # rubocop:disable Rails/SaveBang
        image = upload_fixture("minister-of-funk.960x640.jpg")
        attributes = {
          title: "",
          images_attributes: {
            "0" => {
              alt_text: "some-alt-text",
              image_data_attributes: attributes_for(:image_data, file: image),
            },
          },
        }

        put :update, params: { id: edition, edition: attributes }

        assert_select "form#edit_edition" do
          assert_select "input[name*='edition[images_attributes]'][type='file']", count: 1
        end
      end

      view_test "updating an edition with invalid data and valid image data should display the image data" do
        edition = create(edition_type) # rubocop:disable Rails/SaveBang
        image = upload_fixture("minister-of-funk.960x640.jpg")
        attributes = {
          title: "",
          images_attributes: {
            "0" => {
              alt_text: "some-alt-text",
              image_data_attributes: attributes_for(:image_data, file: image),
            },
          },
        }

        put :update, params: { id: edition, edition: attributes }

        assert_select "form#edit_edition" do
          assert_select "input[name='edition[images_attributes][0][alt_text]'][value='some-alt-text']"
          assert_select "input[name='edition[images_attributes][0][image_data_attributes][file_cache]'][value$='minister-of-funk.960x640.jpg']"
          assert_select ".already_uploaded", text: "minister-of-funk.960x640.jpg already uploaded"
        end
      end

      view_test "updating a stale edition should still display image fields" do
        edition = create("draft_#{edition_type}")
        lock_version = edition.lock_version
        edition.touch

        put :update,
            params: {
              id: edition,
              edition: {
                lock_version:,
              },
            }

        assert_select "form#edit_edition" do
          assert_select "input[name='edition[images_attributes][0][alt_text]'][type='text']"
          assert_select "textarea[name='edition[images_attributes][0][caption]']"
          assert_select "input[name='edition[images_attributes][0][image_data_attributes][file]'][type='file']"
        end
      end

      view_test "updating a stale edition should only allow a single image to be selected for upload" do
        edition = create(edition_type) # rubocop:disable Rails/SaveBang
        image = upload_fixture("minister-of-funk.960x640.jpg")
        lock_version = edition.lock_version
        edition.touch
        attributes = {
          title: "",
          lock_version:,
          images_attributes: { "0" => {
            alt_text: "some-alt-text",
            image_data_attributes: attributes_for(:image_data, file: image),
          } },
        }

        put :update, params: { id: edition, edition: attributes }

        assert_select "form#edit_edition" do
          assert_select "input[name*='edition[images_attributes]'][type='file']", count: 1
        end
      end

      view_test "updating should allow removal of images" do
        Services.asset_manager.stubs(:whitehall_asset).returns("id" => "http://asset-manager/assets/asset-id")
        image = upload_fixture("minister-of-funk.960x640.jpg", "image/jpg")

        edition = create(edition_type) # rubocop:disable Rails/SaveBang
        image1 = create(
          :image,
          edition:,
          alt_text: "the first image",
          image_data_attributes: attributes_for(:image_data, file: image),
        )
        image2 = create(
          :image,
          edition:,
          alt_text: "the second image",
          image_data_attributes: attributes_for(:image_data, file: image),
        )

        attributes = {
          images_attributes: {
            "0" => { id: image1.id.to_s, _destroy: "1" },
            "1" => { id: image2.id.to_s, _destroy: "0" },
            "2" => { image_data_attributes: { file_cache: "" } },
          },
        }
        put :update, params: { id: edition, edition: attributes }

        refute_select ".errors"
        edition.reload
        assert_equal [image2], edition.images
      end
    end

    def legacy_should_allow_references_to_statistical_data_sets_for(edition_type)
      edition_class = class_for(edition_type)

      view_test "new should display statistical data sets field" do
        get :new

        assert_select "form#new_edition" do
          assert_select "#edition_statistical_data_set_document_ids" do |elements|
            assert_equal 1, elements.length
            assert_data_attributes_for_statistical_data_sets(
              element: elements.first,
              track_label: new_edition_path(edition_type),
            )
          end
        end
      end

      test "create should associate statistical data sets with edition" do
        first_data_set = create(:statistical_data_set, document: create(:document))
        second_data_set = create(:statistical_data_set, document: create(:document))
        attributes = controller_attributes_for(edition_type)

        post :create,
             params: {
               edition: attributes.merge(
                 statistical_data_set_document_ids: [first_data_set.document.id, second_data_set.document.id],
               ),
             }

        edition = edition_class.last
        assert_equal [first_data_set, second_data_set], edition.statistical_data_sets
      end

      view_test "edit should display edition statistical data sets field" do
        edition = create(edition_type) # rubocop:disable Rails/SaveBang

        get :edit, params: { id: edition }

        assert_select "form#edit_edition" do
          assert_select "#edition_statistical_data_set_document_ids" do |elements|
            assert_equal 1, elements.length
            assert_data_attributes_for_statistical_data_sets(
              element: elements.first,
              track_label: edit_edition_path(edition_type),
            )
          end
        end
      end

      test "update should associate statistical data sets with editions" do
        first_data_set = create(:statistical_data_set, document: create(:document))
        second_data_set = create(:statistical_data_set, document: create(:document))

        edition = create(edition_type, statistical_data_sets: [first_data_set])

        put :update,
            params: {
              id: edition,
              edition: {
                statistical_data_set_document_ids: [second_data_set.document.id],
              },
            }

        edition.reload
        assert_equal [second_data_set], edition.statistical_data_sets
      end
    end

    def legacy_should_allow_organisations_for(edition_type)
      edition_class = class_for(edition_type)

      view_test "new should display edition organisations fields" do
        get :new

        assert_select "form#new_edition" do
          (1..4).each do |i|
            assert_select("#edition_lead_organisation_ids_#{i}") do |elements|
              assert_equal 1, elements.length
              assert_data_attributes_for_lead_org(element: elements.first, track_label: new_edition_path(edition_type))
            end
          end
          refute_select "#edition_lead_organisation_ids_5"
          (1..6).each do |i|
            assert_select("#edition_supporting_organisation_ids_#{i}") do |elements|
              assert_equal 1, elements.length
              assert_data_attributes_for_supporting_org(element: elements.first, track_label: new_edition_path(edition_type))
            end
          end
          refute_select "#edition_supporting_organisation_ids_7"
        end
      end

      test "new should set first lead organisation to users organisation" do
        editors_org = create(:organisation)
        login_as create(:departmental_editor, organisation: editors_org)

        get :new

        assert_equal assigns(:edition).edition_organisations.first.organisation, editors_org
        assert_equal assigns(:edition).edition_organisations.first.lead, true
        assert_equal assigns(:edition).edition_organisations.first.lead_ordering, 0
      end

      test "create should associate organisations with edition" do
        first_organisation = create(:organisation)
        second_organisation = create(:organisation)
        attributes = controller_attributes_for(edition_type)

        post :create,
             params: {
               edition: attributes.merge(
                 lead_organisation_ids: [second_organisation.id, first_organisation.id],
               ),
             }

        edition = edition_class.last
        assert_equal [second_organisation, first_organisation], edition.lead_organisations
      end

      view_test "edit should display edition organisations field" do
        edition = create(edition_type) # rubocop:disable Rails/SaveBang

        get :edit, params: { id: edition }

        assert_select "form#edit_edition" do
          (1..4).each do |i|
            assert_select("#edition_lead_organisation_ids_#{i}") do |elements|
              assert_equal 1, elements.length
              assert_data_attributes_for_lead_org(element: elements.first, track_label: edit_edition_path(edition_type))
            end
          end
          refute_select "#edition_lead_organisation_ids_5"
          (1..6).each do |i|
            assert_select("#edition_supporting_organisation_ids_#{i}") do |elements|
              assert_equal 1, elements.length
              assert_data_attributes_for_supporting_org(element: elements.first, track_label: edit_edition_path(edition))
            end
          end
          refute_select "#edition_supporting_organisation_ids_7"
        end
      end

      test "update should associate organisations with editions" do
        first_organisation = create(:organisation)
        second_organisation = create(:organisation)

        edition = create(edition_type, organisations: [first_organisation])

        put :update,
            params: {
              id: edition,
              edition: {
                lead_organisation_ids: [second_organisation.id],
              },
            }

        edition.reload
        assert_equal [second_organisation], edition.lead_organisations
      end

      test "update should allow removal of an organisation" do
        organisation1 = create(:organisation)
        organisation2 = create(:organisation)

        edition = create(edition_type, organisations: [organisation1, organisation2])

        put :update,
            params: {
              id: edition,
              edition: {
                lead_organisation_ids: [organisation2.id],
              },
            }

        edition.reload
        assert_equal [organisation2], edition.lead_organisations
      end

      test "update should allow swapping of an organisation from lead to supporting" do
        organisation1 = create(:organisation)
        organisation2 = create(:organisation)
        organisation3 = create(:organisation)

        edition = create(edition_type, organisations: [organisation1, organisation2])
        edition.organisations << organisation3

        put :update,
            params: {
              id: edition,
              edition: {
                lead_organisation_ids: [organisation2.id, organisation3.id],
                supporting_organisation_ids: [organisation1.id],
              },
            }

        edition.reload
        assert_equal [organisation2, organisation3], edition.lead_organisations
        assert_equal [organisation1], edition.supporting_organisations
      end
    end

    def legacy_should_allow_role_appointments_for(edition_type)
      edition_class = class_for(edition_type)

      view_test "new should display edition role appointments field" do
        get :new

        assert_select "form#new_edition" do
          assert_select "#edition_role_appointment_ids" do |elements|
            assert_equal 1, elements.length
            assert_data_attributes_for_ministers(
              element: elements.first,
              track_label: new_edition_path(edition_type),
            )
          end
        end
      end

      test "create should associate role appointments with edition" do
        first_appointment = create(:role_appointment)
        second_appointment = create(:role_appointment)
        attributes = controller_attributes_for(edition_type)

        post :create,
             params: {
               edition: attributes.merge(
                 role_appointment_ids: [first_appointment.id, second_appointment.id],
               ),
             }

        edition = edition_class.last
        assert_equal [first_appointment, second_appointment], edition.role_appointments
      end

      view_test "edit should display edition role appointments field" do
        edition = create(edition_type) # rubocop:disable Rails/SaveBang

        get :edit, params: { id: edition }

        assert_select "form#edit_edition" do
          assert_select "select[name*='edition[role_appointment_ids]']"
        end
      end

      test "update should associate role appointments with editions" do
        first_appointment = create(:role_appointment)
        second_appointment = create(:role_appointment)

        edition = create(edition_type, role_appointments: [first_appointment])

        put :update,
            params: {
              id: edition,
              edition: {
                role_appointment_ids: [second_appointment.id],
              },
            }

        edition.reload
        assert_equal [second_appointment], edition.role_appointments
      end
    end

    def legacy_should_prevent_modification_of_unmodifiable(edition_type)
      (Edition::UNMODIFIABLE_STATES - %w[deleted]).each do |state|
        test "edit not allowed for #{state} #{edition_type}" do
          edition = create("#{state}_#{edition_type}")

          get :edit, params: { id: edition }

          assert_redirected_to send("admin_#{edition_type}_path", edition)
        end

        test "update not allowed for #{state} #{edition_type}" do
          edition = create("#{state}_#{edition_type}")

          put :update,
              params: {
                id: edition,
                edition: {
                  title: "new-title",
                },
              }

          assert_redirected_to send("admin_#{edition_type}_path", edition)
        end
      end
    end

    def legacy_should_allow_overriding_of_first_published_at_for(edition_type)
      edition_class = class_for(edition_type)

      view_test "new should display first_published_at fields" do
        get :new

        admin_editions_path = send("admin_#{edition_type.to_s.tableize}_path")
        assert_select "form#new_edition[action='#{admin_editions_path}']" do
          assert_select "label[for=edition_first_published_at]", text: "Its original publication date was *"
          assert_select "select[name*='edition[first_published_at']", count: 5
        end
      end

      view_test "edit should display first_published_at fields" do
        edition = create(edition_type) # rubocop:disable Rails/SaveBang

        get :edit, params: { id: edition }

        admin_edition_path = send("admin_#{edition_type}_path", edition)
        assert_select "form#edit_edition[action='#{admin_edition_path}']" do
          assert_select "label[for=edition_first_published_at]", text: "Its original publication date was *"
          assert_select "select[name*='edition[first_published_at']", count: 5
        end
      end

      test "create should save overridden first_published_at attribute" do
        first_published_at = 3.months.ago
        post :create,
             params: {
               edition: controller_attributes_for(edition_type).merge(first_published_at: 3.months.ago),
             }

        edition = edition_class.last
        assert_equal first_published_at, edition.first_published_at
      end

      test "update should save overridden first_published_at attribute" do
        edition = create(edition_type) # rubocop:disable Rails/SaveBang
        first_published_at = 3.months.ago

        put :update,
            params: {
              id: edition,
              edition: {
                first_published_at:,
              },
            }

        edition.reload
        assert_equal first_published_at, edition.first_published_at
      end
    end

    def legacy_should_allow_setting_first_published_at_during_speed_tagging(edition_type)
      view_test "show should display first_published_at fields when speed tagging" do
        edition = create("imported_#{edition_type}")
        stub_publishing_api_expanded_links_with_taxons(edition.content_id, [])

        get :show, params: { id: edition }

        assert_select "label[for=edition_first_published_at]", text: "First published *"
        assert_select "select[name*='edition[first_published_at']", count: 5
      end
    end

    def legacy_should_report_editing_conflicts_of(edition_type)
      test "editing an existing #{edition_type} should record a RecentEditionOpening" do
        edition = create(edition_type) # rubocop:disable Rails/SaveBang
        get :edit, params: { id: edition }

        assert_equal [current_user], edition.reload.recent_edition_openings.map(&:editor)
      end

      view_test "should not see a warning when editing an edition that nobody has recently edited" do
        edition = create(edition_type) # rubocop:disable Rails/SaveBang
        get :edit, params: { id: edition }

        refute_select ".editing_conflict"
      end

      view_test "should see a warning when editing an edition that someone else has recently edited" do
        edition = create(edition_type) # rubocop:disable Rails/SaveBang
        other_user = create(:author, name: "Joe Bloggs", email: "joe@example.com")
        edition.open_for_editing_as(other_user)
        Timecop.travel 1.hour.from_now

        request.env["HTTPS"] = "on"
        get :edit, params: { id: edition }

        assert_select ".editing_conflict", /Joe Bloggs/ do
          assert_select "img[src^='https']"
        end
        assert_select ".editing_conflict", /1 hour ago/
      end

      test "saving a #{edition_type} should remove any RecentEditionOpening records for the current user" do
        edition = create(edition_type) # rubocop:disable Rails/SaveBang
        edition.open_for_editing_as(@current_user)

        assert_difference "edition.reload.recent_edition_openings.count", -1 do
          put :update,
              params: {
                id: edition,
                edition: {
                  summary: "A summary",
                },
              }
        end
      end
    end

    def legacy_should_allow_association_with_related_mainstream_content(edition_type)
      edition_class = class_for(edition_type)

      view_test "new should display fields for related mainstream content" do
        get :new

        admin_editions_path = send("admin_#{edition_type}s_path")
        assert_select "form#new_edition[action='#{admin_editions_path}']" do
          assert_select "input[name*='edition[related_mainstream_content_url]']"
          assert_select "input[name*='edition[additional_related_mainstream_content_url]']"
        end
      end

      view_test "edit should display fields for related mainstream content" do
        edition = create(edition_type) # rubocop:disable Rails/SaveBang
        get :edit, params: { id: edition }

        admin_editions_path = send("admin_#{edition_type}_path", edition)
        assert_select "form#edit_edition[action='#{admin_editions_path}']" do
          assert_select "input[name*='edition[related_mainstream_content_url]']"
          assert_select "input[name*='edition[additional_related_mainstream_content_url]']"
        end
      end

      test "create should allow setting of related mainstream content urls" do
        Services.publishing_api.stubs(:lookup_content_ids).with(base_paths: ["/starting-to-export", "/vat-rates"]).returns("/starting-to-export" => "af70706d-1286-49a8-a597-b3715f29edb5", "/vat-rates" => "c621b246-aa0e-44ad-b320-5a9c16c1123b")

        post :create,
             params: {
               edition: controller_attributes_for(edition_type).merge(
                 related_mainstream_content_url: "https://www.gov.uk/starting-to-export",
                 additional_related_mainstream_content_url: "https://www.gov.uk/vat-rates",
               ),
             }

        edition = edition_class.last
        assert_equal "https://www.gov.uk/starting-to-export", edition.related_mainstream_content_url
        assert_equal "https://www.gov.uk/vat-rates", edition.additional_related_mainstream_content_url
      end

      test "update should allow setting of a related mainstream content url" do
        Services.publishing_api.stubs(:lookup_content_ids).with(base_paths: ["/starting-to-export", "/vat-rates"]).returns("/starting-to-export" => "af70706d-1286-49a8-a597-b3715f29edb5", "/vat-rates" => "c621b246-aa0e-44ad-b320-5a9c16c1123b")

        edition = create(
          edition_type,
          related_mainstream_content_url: "https://www.gov.uk/starting-to-export",
          additional_related_mainstream_content_url: "https://www.gov.uk/vat-rates",
        )
        Services.publishing_api.stubs(:lookup_content_ids).with(base_paths: ["/fishing-licences", "/set-up-business-uk"]).returns("/fishing-licences" => "bc46370c-2f2b-4db7-bf23-ace64b465eca", "/set-up-business-uk" => "5e5bb54d-e471-4d07-977b-291168569f26")

        put :update,
            params: {
              id: edition,
              edition: {
                related_mainstream_content_url: "https://www.gov.uk/fishing-licences",
                additional_related_mainstream_content_url: "https://www.gov.uk/set-up-business-uk",
              },
            }

        edition.reload
        assert_equal "https://www.gov.uk/fishing-licences", edition.related_mainstream_content_url
        assert_equal "https://www.gov.uk/set-up-business-uk", edition.additional_related_mainstream_content_url
      end
    end

    def legacy_should_allow_alternative_format_provider_for(edition_type)
      view_test "when creating allow selection of alternative format provider for #{edition_type}" do
        get :new

        assert_select "form#new_edition" do
          assert_select "select[name='edition[alternative_format_provider_id]']"
        end
      end

      view_test "when editing allow selection of alternative format provider for #{edition_type}" do
        draft = create("draft_#{edition_type}")

        get :edit, params: { id: draft }

        assert_select "form#edit_edition" do
          assert_select "select[name='edition[alternative_format_provider_id]']"
        end
      end

      test "update should save modified #{edition_type} alternative format provider" do
        organisation = create(:organisation_with_alternative_format_contact_email)
        edition = create(edition_type) # rubocop:disable Rails/SaveBang

        put :update,
            params: {
              id: edition,
              edition: {
                alternative_format_provider_id: organisation.id,
              },
            }

        saved_edition = edition.reload
        assert_equal organisation, saved_edition.alternative_format_provider
      end
    end

    def legacy_should_allow_access_limiting_of(edition_type)
      edition_class = class_for(edition_type)

      test "create should record the access_limited flag" do
        organisation = create(:organisation)
        controller.current_user.organisation = organisation
        controller.current_user.save!

        post :create,
             params: {
               edition: controller_attributes_for(edition_type).merge(
                 first_published_at: Date.parse("2010-10-21"),
                 access_limited: "1",
                 lead_organisation_ids: [organisation.id],
               ),
             }

        created_publication = edition_class.last
        assert_not created_publication.nil?
        assert created_publication.access_limited?
      end

      view_test "edit displays persisted access_limited flag" do
        publication = create(edition_type, access_limited: false)

        get :edit, params: { id: publication }

        assert_select "form#edit_edition" do
          assert_select "input[name='edition[access_limited]'][type=checkbox]"
          assert_select "input[name='edition[access_limited]'][type=checkbox][checked=checked]", count: 0
        end
      end

      test "update records new value of access_limited flag" do
        controller.current_user.organisation = create(:organisation)
        controller.current_user.save!
        publication = create(edition_type, access_limited: false, organisations: [controller.current_user.organisation])

        put :update,
            params: {
              id: publication,
              edition: {
                access_limited: "1",
              },
            }

        assert publication.reload.access_limited?
      end
    end

    def legacy_should_allow_relevance_to_local_government_of(edition_type)
      edition_class = class_for(edition_type)

      test "create should record the relevant_to_local_government flag" do
        post :create,
             params: {
               edition: controller_attributes_for(
                 edition_type,
                 first_published_at: Date.parse("2010-10-21"),
                 relevant_to_local_government: "1",
               ),
             }

        created_publication = edition_class.last!
        assert created_publication.relevant_to_local_government?
      end

      view_test "edit displays persisted relevant_to_local_government flag" do
        publication = create(edition_type, relevant_to_local_government: false)

        get :edit, params: { id: publication }

        assert_select "form#edit_edition" do
          assert_select "input[name='edition[relevant_to_local_government]'][type=checkbox]"
          assert_select "input[name='edition[relevant_to_local_government]'][type=checkbox][checked=checked]", count: 0
        end
      end

      test "update records new value of relevant_to_local_government flag" do
        publication = create(edition_type, relevant_to_local_government: false)

        put :update,
            params: {
              id: publication,
              edition: {
                relevant_to_local_government: "1",
              },
            }

        assert publication.reload.relevant_to_local_government?
      end
    end

    def legacy_should_allow_association_with_topical_events(edition_type)
      edition_class = class_for(edition_type)

      view_test "new should display topical events field" do
        get :new

        assert_select "form#new_edition" do
          assert_select "#edition_topical_event_ids" do |elements|
            assert_equal 1, elements.length
            assert_data_attributes_for_topical_events(
              element: elements.first,
              track_label: new_edition_path(edition_type),
            )
          end
        end
      end

      test "create should associate topical events with the edition" do
        first_topical_event = create(:topical_event)
        second_topical_event = create(:topical_event)
        attributes = controller_attributes_for(edition_type)

        post :create,
             params: {
               edition: attributes.merge(
                 topical_event_ids: [first_topical_event.id, second_topical_event.id],
               ),
             }

        edition = edition_class.last!
        assert_equal [first_topical_event, second_topical_event], edition.topical_events
      end

      view_test "edit should display topical events field" do
        edition = create("draft_#{edition_type}")

        get :edit, params: { id: edition }

        assert_select "form#edit_edition" do
          assert_select "#edition_topical_event_ids" do |elements|
            assert_equal 1, elements.length
            assert_data_attributes_for_topical_events(
              element: elements.first,
              track_label: edit_edition_path(edition_type),
            )
          end
        end
      end

      test "update should associate topical events with the edition" do
        first_topical_event = create(:topical_event)
        second_topical_event = create(:topical_event)

        edition = create("draft_#{edition_type}", topical_events: [first_topical_event])

        put :update,
            params: {
              id: edition,
              edition: {
                topical_event_ids: [second_topical_event.id],
              },
            }

        edition.reload
        assert_equal [second_topical_event], edition.topical_events
      end
    end

    def legacy_should_allow_association_with_worldwide_organisations(edition_type)
      edition_class = class_for(edition_type)

      view_test "new should display worldwide organisations field" do
        get :new

        assert_select "form#new_edition" do
          assert_select "#edition_worldwide_organisation_ids" do |elements|
            assert_equal 1, elements.length
            assert_data_attributes_for_worldwide_organisations(
              element: elements.first,
              track_label: new_edition_path(edition_type),
            )
          end
        end
      end

      test "should not populate world locations if user doesn't have any" do
        create(:world_location)
        login_as create(:departmental_editor, world_locations: [])
        get :new

        assert_equal assigns(:edition).world_locations, []
      end

      test "should populate world locations with the current users locations" do
        world_location = create(:world_location)
        login_as create(:departmental_editor, world_locations: [world_location])
        get :new

        assert_equal assigns(:edition).world_locations, [world_location]
      end

      view_test "edit should display worldwide organisations field" do
        edition = create(edition_type) # rubocop:disable Rails/SaveBang
        get :edit, params: { id: edition }

        assert_select "form#edit_edition" do
          assert_select "#edition_worldwide_organisation_ids" do |elements|
            assert_equal 1, elements.length
            assert_data_attributes_for_worldwide_organisations(
              element: elements.first,
              track_label: edit_edition_path(edition_type),
            )
          end
        end
      end

      test "create should associate worldwide organisations with the edition" do
        first_world_organisation = create(:worldwide_organisation)
        second_world_organisation = create(:worldwide_organisation)
        attributes = controller_attributes_for(edition_type)

        post :create,
             params: {
               edition: attributes.merge(
                 worldwide_organisation_ids: [first_world_organisation.id, second_world_organisation.id],
               ),
             }

        edition = edition_class.last!
        assert_equal [first_world_organisation, second_world_organisation], edition.worldwide_organisations
      end
    end
  end

private

  def assert_data_attributes_for_ministers(element:, track_label:)
    assert_equal "Choose ministers…", element["data-placeholder"]
    assert_equal "track-select-click", element["data-module"]
    assert_equal "ministerSelection", element["data-track-category"]
    assert_equal track_label, element["data-track-label"]
  end

  def assert_data_attributes_for_worldwide_organisations(element:, track_label:)
    assert_equal "Worldwide organisations…", element["data-placeholder"]
    assert_equal "track-select-click", element["data-module"]
    assert_equal "worldwideOrganisationSelection", element["data-track-category"]
    assert_equal track_label, element["data-track-label"]
  end

  def assert_data_attributes_for_statistical_data_sets(element:, track_label:)
    assert_equal "Choose statistical data sets…", element["data-placeholder"]
    assert_equal "track-select-click", element["data-module"]
    assert_equal "statisticalDataSetSelection", element["data-track-category"]
    assert_equal track_label, element["data-track-label"]
  end

  def assert_data_attributes_for_topical_events(element:, track_label:)
    assert_equal "Choose topical events…", element["data-placeholder"]
    assert_equal "track-select-click", element["data-module"]
    assert_equal "topicalEventSelection", element["data-track-category"]
    assert_equal track_label, element["data-track-label"]
  end

  def assert_data_attributes_for_lead_org(element:, track_label:)
    assert_equal "Choose a lead organisation which produced this document…", element["data-placeholder"]
    assert_equal "track-select-click", element["data-module"]
    assert_equal "leadOrgSelection", element["data-track-category"]
    assert_equal track_label, element["data-track-label"]
  end

  def assert_data_attributes_for_supporting_org(element:, track_label:)
    assert_equal "Choose a supporting organisation which produced this document…", element["data-placeholder"]
    assert_equal "track-select-click", element["data-module"]
    assert_equal "supportingOrgSelection", element["data-track-category"]
    assert_equal track_label, element["data-track-label"]
  end

  def new_edition_path(edition_type)
    edition = build(edition_type)
    @controller.new_polymorphic_path([:admin, edition])
  end

  def edit_edition_path(edition)
    @controller.edit_polymorphic_path([:admin, edition])
  end
end
