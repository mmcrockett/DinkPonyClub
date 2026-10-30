require 'test_helper'

module Admin
  class DashboardsControllerTest < ActionDispatch::IntegrationTest
    test 'redirects to root when signed in as a non-admin' do
      sign_in_as players(:ada)

      get admin_root_path

      assert_redirected_to root_path
    end

    test 'warns an admin when database backups are overdue' do
      sign_in_as players(:zoe)

      with_backup_warning(true) { get admin_root_path }

      assert_select '[role=alert]', text: /Database backups are not working/
    end

    test 'shows no backup warning when backups are healthy or not configured' do
      sign_in_as players(:zoe)

      get admin_root_path

      assert_select '[role=alert]', count: 0
    end

    test 'shows fees, email the league and payment requests to an admin' do
      sign_in_as players(:zoe)
      season = seasons(:fall)

      get admin_root_path

      assert_response :success
      assert_select "a[href='#{admin_fees_path(season: season)}']"
      assert_select "a[href='#{new_admin_announcement_path(season: season)}']"
      assert_select "form[action='#{admin_payment_requests_path(season: season)}']"
      assert_select "a[href='#{admin_roster_path(season: season)}']"
    end

    test 'asks an admin to create a season first when none exists' do
      sign_in_as players(:zoe)
      Season.destroy_all

      get admin_root_path

      assert_response :success
      assert_select 'nav[aria-label=Admin]', count: 0
      assert_select 'p', text: 'Create a season first.'
    end

    private

    def with_backup_warning(value)
      original = DatabaseBackup.method(:warn?)
      DatabaseBackup.define_singleton_method(:warn?) { value }
      yield
    ensure
      DatabaseBackup.define_singleton_method(:warn?, original)
    end
  end
end
