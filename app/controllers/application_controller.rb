# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern, unless: :skip_browser_gate?

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def skip_browser_gate?
    false
  end
end
