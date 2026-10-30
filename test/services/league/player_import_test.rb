require 'test_helper'

module League
  class PlayerImportTest < ActiveSupport::TestCase
    test 'adds a player with a split name, phone and case-insensitive school' do
      result = PlayerImport.new('New@Example.test, Ann Marie Lee, 555-123-4567, lincoln high').call
      player = Player.find_by!(email: 'new@example.test')

      assert_equal 1, result.added
      assert_equal ['Ann Marie', 'Lee', '555-123-4567'], [player.first_name, player.last_name, player.phone]
      assert_equal schools(:lincoln), player.school
    end

    test 'leaves the school unknown when it does not match' do
      PlayerImport.new('new@example.test, Ann Lee,, Nowhere High').call

      assert_nil Player.find_by!(email: 'new@example.test').school
    end

    test 'counts existing emails and phones as existed' do
      text = <<~TEXT
        ADA@example.test, Ada Again
        other@example.test, Sam Again, (512) 555-0101
      TEXT

      result = PlayerImport.new(text).call

      assert_equal [0, 2], [result.added, result.existed]
    end

    test 'counts a repeat within the paste as existed' do
      result = PlayerImport.new("a@example.test, A One\na@example.test, A Two\n").call

      assert_equal [1, 1], [result.added, result.existed]
    end

    test 'counts bad lines as junk and ignores blank lines' do
      text = "email,name,phone,school\n\nnot-an-email, Bob Ray\nbob@example.test,\n"

      result = PlayerImport.new(text).call

      assert_equal [3, 3, 0], [result.read, result.junk, result.added]
    end
  end
end
