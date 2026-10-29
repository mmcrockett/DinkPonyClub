require 'test_helper'

class DatabaseBackupJobTest < ActiveJob::TestCase
  test 'does nothing when there is no mysql_backup config' do
    assert_nil DatabaseBackupJob.perform_now
  end

  test 'is scheduled hourly in production' do
    entry = YAML.load_file(Rails.root.join('config/recurring.yml')).dig('production', 'backup_database_to_mysql')

    assert_equal DatabaseBackupJob, entry['class'].constantize
    assert_match(/every hour/, entry['schedule'])
  end
end
