require 'rails_helper'
require Rails.root.join('lib/security_headers').to_s

# Security headers must be present on EVERY response — including static assets
# and error pages that bypass Rails' controller-level default headers
# (ASVS V14; ZAP 10021/10063/90004).
RSpec.describe SecurityHeaders do
  let(:downstream) { { 'Content-Type' => 'text/html' } }
  let(:app) { ->(_env) { [ 200, downstream.dup, [ 'body' ] ] } }
  subject(:headers) { described_class.new(app).call({})[1] }

  it "sets x-content-type-options: nosniff" do
    expect(headers['x-content-type-options']).to eq('nosniff')
  end

  it "sets a restrictive permissions-policy" do
    expect(headers['permissions-policy']).to include('camera=()')
  end

  it "sets referrer-policy and x-frame-options" do
    expect(headers['referrer-policy']).to eq('strict-origin-when-cross-origin')
    expect(headers['x-frame-options']).to eq('SAMEORIGIN')
  end

  it "sets cross-origin isolation headers (COOP/CORP)" do
    expect(headers['cross-origin-opener-policy']).to eq('same-origin')
    expect(headers['cross-origin-resource-policy']).to eq('same-origin')
  end

  it "leaves content-security-policy to the app (per-request nonce)" do
    expect(headers).not_to have_key('content-security-policy')
  end

  it "passes the downstream status and body through untouched" do
    status, _h, body = described_class.new(app).call({})
    expect(status).to eq(200)
    expect(body).to eq([ 'body' ])
  end
end
