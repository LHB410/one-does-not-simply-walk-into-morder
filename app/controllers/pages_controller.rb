# Public, static informational pages (Privacy Policy, Terms of Service). No
# login required — these must be reachable from the logged-out landing screen.
class PagesController < ApplicationController
  def privacy; end

  def terms; end
end
