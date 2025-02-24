Feature: New Tagging Workflow
  In order to get more publishers tagging to the new taxonomy
  Whitehall Needs to alter it's tagging workflow to remove editing
  legacy associations from the main edit screen.

  The flow is now as follows:

  For a publication that uses the new taxonomy :
    Edit Screen > Next > Taxonomy Tagging Screen > Save > Admin Screen

  For a publication that does not use the new taxonomy:
    Edit Screen > Next > Legacy Tagging Screen > Save > Admin Screen

Scenario: Publication that does not support the new taxonomy
  Given I am a writer
  When I start editing a draft document which cannot be tagged to the new taxonomy
  And I continue to the legacy tagging page
  Then I should be on the legacy tagging page
  And I should be able to update the legacy tags

Scenario: Publication that supports the new taxonomy
  Given I am a writer
  When I start editing a draft document which can be tagged to the new taxonomy
  And I continue to the tagging page
  Then I should be on the taxonomy tagging page
  And I should be able to update the taxonomy and click the "Save tagging changes" button

Scenario: Publication that supports the new taxonomy with the Preview design system permission
  Given I am a writer
  And I have the "Preview design system" permission
  When I start editing a draft document which can be tagged to the new taxonomy
  And I continue to the tagging page
  Then I should be on the taxonomy tagging page
  And I should be able to update the taxonomy and click the "Update tags" button
