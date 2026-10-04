require 'test_helper'

class NavigationHelperTest < ActionView::TestCase
  test 'app_version reads APP_VERSION and is nil when blank' do
    with_env('APP_VERSION' => '52') { assert_equal '52', app_version }
    with_env('APP_VERSION' => '') { assert_nil app_version }
  end

  test 'app_revision is the short KAMAL_VERSION sha' do
    with_env('KAMAL_VERSION' => '002a32d1234567890') { assert_equal '002a32d', app_revision }
    with_env('KAMAL_VERSION' => nil) { assert_nil app_revision }
  end

  test 'app_built_at formats APP_BUILT_AT in UTC and is nil when blank' do
    with_env('APP_BUILT_AT' => '2026-10-04T12:22:53-05:00') { assert_equal '2026-10-04 17:22 UTC', app_built_at }
    with_env('APP_BUILT_AT' => '') { assert_nil app_built_at }
  end

  test 'app_version_title joins the sha and build time, skipping what is missing' do
    with_env('KAMAL_VERSION' => '002a32d1234567890', 'APP_BUILT_AT' => '2026-10-04T17:22:53Z') do
      assert_equal '002a32d - 2026-10-04 17:22 UTC', app_version_title
    end
    with_env('KAMAL_VERSION' => '002a32d1234567890', 'APP_BUILT_AT' => '') { assert_equal '002a32d', app_version_title }
    with_env('KAMAL_VERSION' => nil, 'APP_BUILT_AT' => '') { assert_nil app_version_title }
  end

  private

  def with_env(vars)
    old = vars.keys.index_with { |key| ENV.fetch(key, nil) }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    old.each { |key, value| ENV[key] = value }
  end
end
