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

  private

  def with_env(vars)
    old = vars.keys.index_with { |key| ENV.fetch(key, nil) }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    old.each { |key, value| ENV[key] = value }
  end
end
