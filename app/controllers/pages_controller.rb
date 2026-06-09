# Public, static informational pages (Privacy Policy, Terms of Service). No login
# required. The public homepage itself is the logged-out root (dashboard#index).
class PagesController < ApplicationController
  def privacy; end

  def terms; end
end
