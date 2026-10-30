require 'test_helper'

class DatabaseBackupTest < ActiveSupport::TestCase
  test 'is overdue when no backup has been recorded' do
    assert_predicate DatabaseBackup, :overdue?
  end

  test 'is not overdue right after a recorded success' do
    DatabaseBackup.record_success

    assert_not_predicate DatabaseBackup, :overdue?
  end

  test 'is overdue when the last success is older than the window' do
    Rails.cache.write(DatabaseBackup::CACHE_KEY, 4.hours.ago)

    assert_predicate DatabaseBackup, :overdue?
  end

  test 'does not warn when no mysql_backup database is configured' do
    assert_not DatabaseBackup.warn?
  end
end
