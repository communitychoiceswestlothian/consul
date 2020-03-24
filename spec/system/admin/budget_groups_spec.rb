require "rails_helper"

describe "Admin budget groups" do
  let(:budget) { create(:budget, :drafting) }

  before do
    admin = create(:administrator)
    login_as(admin.user)
  end

  context "Feature flag" do
    before do
      Setting["process.budgets"] = nil
    end

    scenario "Disabled with a feature flag" do
      expect do
        visit admin_budget_groups_path(budget)
      end.to raise_exception(FeatureFlags::FeatureDisabled)
    end
  end

  context "Load" do
    let!(:budget) { create(:budget, slug: "budget_slug") }
    let!(:group)  { create(:budget_group, slug: "group_slug", budget: budget) }

    scenario "finds budget and group by slug" do
      visit edit_admin_budget_group_path("budget_slug", "group_slug")
      expect(page).to have_content(budget.name)
      expect(page).to have_field "Group name", with: group.name
    end

    scenario "raises an error if budget slug is not found" do
      expect do
        visit edit_admin_budget_group_path("wrong_budget", group)
      end.to raise_error ActiveRecord::RecordNotFound
    end

    scenario "raises an error if budget id is not found" do
      expect do
        visit edit_admin_budget_group_path(0, group)
      end.to raise_error ActiveRecord::RecordNotFound
    end

    scenario "raises an error if group slug is not found" do
      expect do
        visit edit_admin_budget_group_path(budget, "wrong_group")
      end.to raise_error ActiveRecord::RecordNotFound
    end

    scenario "raises an error if group id is not found" do
      expect do
        visit edit_admin_budget_group_path(budget, 0)
      end.to raise_error ActiveRecord::RecordNotFound
    end
  end

  context "List of groups from budget edit view" do
    scenario "Displaying no groups for budget" do
      visit admin_budget_path(budget)

      expect(page).not_to have_selector "h3"
    end

    scenario "Displaying groups" do
      group1 = create(:budget_group, budget: budget)
      group2 = create(:budget_group, budget: budget, max_votable_headings: 2)

      visit admin_budget_path(budget)
      expect(page).to have_selector "h3", count: 2

      within "#group_#{group1.id}" do
        expect(page).to have_content "Maximum number of headings in which a user can vote 1"
        expect(page).to have_selector "h3", text: group1.name
      end

      within "#group_#{group2.id}" do
        expect(page).to have_content "Maximum number of headings in which a user can vote 2"
        expect(page).to have_selector "h3", text: group2.name
      end
    end

    scenario "Delete a group without headings" do
      group = create(:budget_group, budget: budget)

      visit admin_budget_path(budget)

      expect(page).to have_selector "#group_#{group.id}"
      click_link "delete_group_#{group.id}"

      expect(page).to have_content "Group deleted successfully"
      expect(page).not_to have_selector "#group_#{group.id}"
    end

    scenario "Try to delete a group with headings" do
      group = create(:budget_group, budget: budget)
      create(:budget_heading, group: group)

      visit admin_budget_path(budget)

      expect(page).to have_selector "#group_#{group.id}"
      click_link "delete_group_#{group.id}"

      expect(page).to have_content "You cannot delete a Group that has associated headings"
      expect(page).to have_selector "#group_#{group.id}"
    end
  end

  context "New" do
    scenario "Create group" do
      visit admin_budget_path(budget)
      click_link "Add group"

      fill_in "Group name", with: "All City"
      click_button "Create new group"

      expect(page).to have_content "Group created successfully!"
      expect(page).to have_selector "h3", count: 1

      group = Budget::Group.last
      within("#group_#{group.id}") { expect(page).to have_selector "h3", text: group.name }
    end

    scenario "Maximum number of headings in which a user can vote is set to 1 by default" do
      visit new_admin_budget_group_path(budget)

      fill_in "Group name", with: "All City"
      click_button "Create new group"

      expect(page).to have_content "Group created successfully!"
      expect(Budget::Group.first.max_votable_headings).to be 1
    end

    scenario "Group name is mandatory" do
      visit new_admin_budget_group_path(budget)

      click_button "Create new group"

      expect(page).not_to have_content "Group created successfully!"
      expect(page).to have_css(".is-invalid-label", text: "Group name")
      expect(page).to have_content "can't be blank"
    end
  end

  context "Edit" do
    scenario "Show group information" do
      group = create(:budget_group, budget: budget, max_votable_headings: 2)
      2.times { create(:budget_heading, group: group) }

      visit admin_budget_path(budget)
      click_link "edit_group_#{group.id}"

      expect(page).to have_field "Group name", with: group.name
      expect(page).to have_field "Maximum number of headings in which a user can select projects", with: "2"
    end

    scenario "Hide select for maxium number of headings to vote if there are no headings for the group" do
      group_without_headings = create(:budget_group, budget: budget)
      group_with_headings    = create(:budget_group, budget: budget)
      create(:budget_heading, group: group_with_headings)

      visit edit_admin_budget_group_path(budget, group_with_headings)
      expect(page).to have_field "Maximum number of headings in which a user can vote"

      visit edit_admin_budget_group_path(budget, group_without_headings)
      expect(page).not_to have_field "Maximum number of headings in which a user can vote"
    end

    scenario "Changing name for current locale will update the slug if budget is in draft phase", :js do
      group = create(:budget_group, budget: budget)
      old_slug = group.slug

      visit edit_admin_budget_group_path(budget, group)

      select "Español", from: :add_language
      fill_in "Group name", with: "Spanish name"
      click_button "Save group"

      expect(page).to have_content "Group updated successfully"
      expect(group.reload.slug).to eq old_slug

      visit edit_admin_budget_group_path(budget, group)

      select "English", from: :select_language
      fill_in "Group name", with: "New English Name"
      click_button "Save group"

      expect(page).to have_content "Group updated successfully"
      expect(group.reload.slug).not_to eq old_slug
      expect(group.slug).to eq "new-english-name"
    end
  end

  context "Update" do
    let!(:group) { create(:budget_group, budget: budget, name: "All City") }

    scenario "Updates group" do
      2.times { create(:budget_heading, group: group) }

      visit edit_admin_budget_group_path(budget, group)
      expect(page).to have_field "Group name", with: "All City"

      fill_in "Group name", with: "Districts"
      select "2", from: "Maximum number of headings in which a user can select projects"
      click_button "Save group"

      expect(page).to have_content "Group updated successfully"

      visit edit_admin_budget_group_path(budget, group)
      expect(page).to have_field "Group name", with: "Districts"
      expect(page).to have_field "Maximum number of headings in which a user can select projects", with: "2"
    end

    scenario "Group name is already used" do
      create(:budget_group, budget: budget, name: "Districts")

      visit edit_admin_budget_group_path(budget, group)
      expect(page).to have_field "Group name", with: "All City"

      fill_in "Group name", with: "Districts"
      click_button "Save group"

      expect(page).not_to have_content "Group updated successfully"
      expect(page).to have_css(".is-invalid-label", text: "Group name")
      expect(page).to have_css("small.form-error", text: "has already been taken")
    end
  end
end
