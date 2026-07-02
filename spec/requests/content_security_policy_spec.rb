require 'rails_helper'

# A Content-Security-Policy must be sent and must not weaken script execution
# with 'unsafe-inline'/'unsafe-eval' (ASVS V14 / SECURITY_AUDIT P3).
RSpec.describe "Content-Security-Policy", type: :request do
  let(:csp) { response.headers["Content-Security-Policy"] }

  before { get root_path }

  it "is sent on responses" do
    expect(csp).to be_present
  end

  it "locks defaults and forbids plugins" do
    expect(csp).to include("default-src 'self'")
    expect(csp).to include("object-src 'none'")
    expect(csp).to include("base-uri 'self'")
  end

  it "allows only self and a per-request nonce for scripts (no external hosts)" do
    script_src = csp[/script-src[^;]*/]
    expect(script_src).to include("'self'")
    expect(script_src).to include("'nonce-")
    expect(script_src).not_to match(%r{https?://})
  end

  it "never permits unsafe-inline or unsafe-eval for scripts" do
    script_src = csp[/script-src[^;]*/]
    expect(script_src).not_to include("unsafe-inline")
    expect(script_src).not_to include("unsafe-eval")
  end

  it "permits inline styles (Turbo + inline style attributes) without weakening scripts" do
    expect(csp).to match(/style-src [^;]*'unsafe-inline'/)
  end

  it "defines form-action (which does not fall back to default-src)" do
    expect(csp).to include("form-action 'self'")
  end

  it "does not allow a broad https: wildcard for images" do
    img_src = csp[/img-src[^;]*/]
    expect(img_src).to eq("img-src 'self' data:")
  end
end
