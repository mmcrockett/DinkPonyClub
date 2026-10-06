require 'test_helper'

class AnnouncementFormTest < ActiveSupport::TestCase
  test 'requires subject and body' do
    form = AnnouncementForm.new

    assert_not form.valid?
    assert_includes form.errors.attribute_names, :subject
    assert_includes form.errors.attribute_names, :body
  end

  test 'rejects an unknown audience' do
    assert_not AnnouncementForm.new(subject: 'a', body: 'b', audience: 'nobody').valid?
  end

  test 'roster audience is the season roster' do
    form = AnnouncementForm.new(subject: 'a', body: 'b')

    assert_equal seasons(:fall).players.active.by_name.to_a, form.recipients(seasons(:fall)).to_a
  end

  test 'all audience is every active player' do
    form = AnnouncementForm.new(subject: 'a', body: 'b', audience: 'all')

    assert_equal Player.active.by_name.to_a, form.recipients(seasons(:fall)).to_a
  end
end
