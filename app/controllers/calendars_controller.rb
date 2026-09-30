# frozen_string_literal: true

# Calendar clients fetch with no cookies and non-browser user agents, so this
# skips ApplicationController's session auth and allow_browser gate; the token
# in the URL is the credential.
class CalendarsController < ActionController::Base # rubocop:disable Rails/ApplicationController
  include SeasonScoped

  def show
    player = Player.active.find_by(calendar_token: params[:token].to_s)
    return head :not_found unless player

    calendar = PlayerCalendar.new(player, current_season, night_url: ->(night) { match_night_url(night) })
    return unless stale?(etag: calendar.cache_key, last_modified: calendar.last_modified, public: false)

    render plain: calendar.to_ical, content_type: 'text/calendar'
  end
end
