require 'application_system_test_case'

class ScorecardEntryTest < ApplicationSystemTestCase
  HOME = %i[sc_home_captain sc_home_player1 sc_home_player2 sc_home_player3 sc_home_player4
            sc_home_player5 sc_home_player6 sc_home_player7 sc_home_player8 sc_home_player9].freeze
  AWAY = %i[sc_away_captain sc_away_player1 sc_away_player2 sc_away_player3 sc_away_player4
            sc_away_player5 sc_away_player6 sc_away_player7 sc_away_player8 sc_away_player9].freeze

  setup do
    @match = matches(:scorecard_match)
    ScorecardForm.new(match: @match, lines: seated_lines).save
    sign_in_as players(:zoe), return_to: edit_match_path(@match)
  end

  test 'a complete score pair auto-saves without pressing Done' do
    score_field('home').set('11')
    score_field('away').set('7')

    assert_text 'Saved'

    visit edit_match_path(@match)

    assert_equal '11', score_field('home').value
  end

  test 'a half-filled row holds the save and says what is missing' do
    score_field('home').set('1')

    assert_text 'Not saved - finish Line 1 Game 2'
  end

  test 'typing two digits moves focus to the next score box' do
    score_field('home').set('11')

    assert_equal 'Line 1 game 2 away score', page.evaluate_script('document.activeElement.getAttribute("aria-label")')
  end

  test 'editing the lineup swaps the summary for the editor until it is set again' do
    click_on 'Edit'

    assert_selector 'h2', text: /set the lineup/i

    click_on 'Set lineup'

    assert_selector 'h2', text: /\Alineup\z/i
    assert_no_selector 'h2', text: /set the lineup/i
  end

  private

  def score_field(side)
    find("input[aria-label='Line 1 game 2 #{side} score']")
  end

  def seated_lines
    @match.line_positions.to_h do |position|
      index = (position - 1) * 2
      [position, { home_player_ids: HOME[index, 2].map { |key| players(key).id.to_s },
                   away_player_ids: AWAY[index, 2].map { |key| players(key).id.to_s },
                   home_score1: '11', away_score1: '5' }]
    end
  end
end
