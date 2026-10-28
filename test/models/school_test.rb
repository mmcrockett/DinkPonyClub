require 'test_helper'

class SchoolTest < ActiveSupport::TestCase
  test 'requires a unique name' do
    assert_not School.new(name: '').valid?
    assert_not School.new(name: schools(:lincoln).name).valid?
  end

  test 'accepts a png icon' do
    school = School.new(name: 'New')
    school.icon.attach(io: StringIO.new('x'), filename: 'a.png', content_type: 'image/png')

    assert_predicate school, :valid?
  end

  test 'rejects svg and oversized icons' do
    school = School.new(name: 'New')
    school.icon.attach(io: StringIO.new('<svg/>'), filename: 'a.svg', content_type: 'image/svg+xml')

    assert_not school.valid?

    school.icon.attach(io: StringIO.new('x' * (School::MAX_ICON_BYTES + 1)), filename: 'a.png',
                       content_type: 'image/png')

    assert_not school.valid?
    assert_includes school.errors.full_messages_for(:icon), 'Icon must be under 1 MB'
  end

  test 'destroying a school sets its players back to unknown' do
    player = players(:ada)
    player.update!(school: schools(:lincoln))

    schools(:lincoln).destroy!

    assert_nil player.reload.school_id
  end
end
