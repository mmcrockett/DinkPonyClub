require 'test_helper'

class PlayersHelperTest < ActionView::TestCase
  test 'rating_change_class is green for a gain' do
    assert_equal 'text-dpc-green', rating_change_class(0.04)
  end

  test 'rating_change_class is red for a loss' do
    assert_equal 'text-red-700', rating_change_class(-13)
  end

  test 'rating_change_class is gray for no change' do
    assert_equal 'text-gray-500', rating_change_class(0)
  end
end
