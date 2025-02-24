class Feature < ApplicationRecord
  include LockedDocumentConcern
  belongs_to :document
  belongs_to :topical_event
  belongs_to :offsite_link
  belongs_to :feature_list

  before_save { check_if_locked_document(document:) }

  mount_uploader :image, ImageUploader, mount_on: :carrierwave_image
  validates :document, presence: true, unless: ->(feature) { feature.topical_event_id.present? || feature.offsite_link_id.present? }
  validates :started_at, presence: true
  validates :image, presence: true, on: :create
  validates :alt_text, presence: true, allow_blank: true, on: :create
  validates :alt_text, length: { maximum: 255 }
  validates_with ImageValidator, method: :image, size: [960, 640], if: :image_changed?

  before_validation :set_started_at!, on: :create

  delegate :republish_featurable_to_publishing_api, to: :feature_list

  def to_s
    if document && document.live_edition
      LocalisedModel.new(document.live_edition, locale).title
    elsif topical_event
      topical_event.name
    elsif offsite_link
      offsite_link.title
    else
      "Feature #{id}"
    end
  end

  def self.current
    where(ended_at: nil)
  end

  def self.with_published_edition
    joins(document: :live_edition)
  end

  def self.with_topical_events
    joins(:topical_event)
  end

  def end!
    self.ended_at = Time.zone.now
    save!
  end

  def locale
    feature_list ? feature_list.locale : :en
  end

private

  def set_started_at!
    self.started_at = Time.zone.now
  end

  def image_changed?
    changes["carrierwave_image"].present?
  end
end
