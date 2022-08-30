require "test_helper"

class FeatureTest < ActiveSupport::TestCase
  extend Minitest::Spec::DSL
  
  context "when the featurable is an organisation" do
    test "creating a new feature republishes the linked featurable" do
      test_object = create(:organisation)
      feature_list = create(:feature_list, featurable: test_object)
      Whitehall::PublishingApi.expects(:republish_async).with(test_object).once
      create(:feature, feature_list: feature_list)
    end

    test "updating an existing feature republishes the linked featurable" do
      test_object = create(:organisation)
      feature_list = create(:feature_list, featurable: test_object)
      feature = create(:feature, feature_list: feature_list)
      feature.alt_text = "Test"
      Whitehall::PublishingApi.expects(:republish_async).with(test_object).once
      feature.save!
    end

    test "deleting a feature republishes the linked featurable" do
      test_object = create(:organisation)
      feature_list = create(:feature_list, featurable: test_object)
      feature = create(:feature, feature_list: feature_list)
      Whitehall::PublishingApi.expects(:republish_async).with(test_object).once
      feature.destroy!
    end
  end

  context "when the featurable is a topical event" do
    test "creating a new feature republishes the linked featurable" do
      test_object = create(:topical_event)
      feature_list = create(:feature_list, featurable: test_object)
      Whitehall::PublishingApi.expects(:republish_async).with(test_object).once
      create(:feature, feature_list: feature_list)
    end

    test "updating an existing feature republishes the linked featurable" do
      test_object = create(:topical_event)
      feature_list = create(:feature_list, featurable: test_object)
      feature = create(:feature, feature_list: feature_list)
      feature.alt_text = "Test"
      Whitehall::PublishingApi.expects(:republish_async).with(test_object).once
      feature.save!
    end

    test "deleting a feature republishes the linked featurable" do
      test_object = create(:topical_event)
      feature_list = create(:feature_list, featurable: test_object)
      feature = create(:feature, feature_list: feature_list)
      Whitehall::PublishingApi.expects(:republish_async).with(test_object).once
      feature.destroy!
    end
  end

  test "creating a new feature does not republish the linked featurable if it's not an Organisation or TopicalEvent" do
    test_object = create(:world_location)
    feature_list = create(:feature_list, featurable: test_object)
    Whitehall::PublishingApi.expects(:republish_async).with(test_object).never
    create(:feature, feature_list: feature_list)
  end
end
