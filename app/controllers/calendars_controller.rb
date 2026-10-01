# frozen_string_literal: true

# Calendar clients fetch with no cookies and non-browser user agents; the
# token in the URL is the credential.
class CalendarsController < ApplicationController
  include SeasonScoped

  skip_before_action :set_current_player

  def show
    player = Player.active.find_by(calendar_token: params[:token].to_s)
    return head :not_found unless player

    calendar = PlayerCalendar.new(player, current_season, night_url: ->(night) { match_night_url(night) })
    return unless stale?(etag: calendar.cache_key, last_modified: calendar.last_modified, public: false)

    render plain: calendar.to_ical, content_type: 'text/calendar'
  end

  private

  def skip_browser_gate?
    true
  end
end
