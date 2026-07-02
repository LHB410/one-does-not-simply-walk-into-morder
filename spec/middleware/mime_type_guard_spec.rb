require 'rails_helper'
require Rails.root.join('lib/mime_type_guard').to_s

# Scanners and broken HTTP clients send malformed Accept/Content-Type headers
# (e.g. a bare "*" instead of "*/*"). Rails raises
# ActionDispatch::Http::MimeNegotiation::InvalidType for these and logs a full
# backtrace on every hit — pure noise from bot traffic. This middleware answers
# a clean 406 and logs a single terse info line instead.
RSpec.describe MimeTypeGuard do
  let(:ok_app) { ->(_env) { [ 200, { 'Content-Type' => 'text/html' }, [ 'ok' ] ] } }
  let(:raising_app) do
    ->(_env) do
      raise ActionDispatch::Http::MimeNegotiation::InvalidType, '"*" is not a valid MIME type'
    end
  end

  def env_for(method: 'GET', path: '/')
    { 'REQUEST_METHOD' => method, 'PATH_INFO' => path }
  end

  it "passes normal requests straight through untouched" do
    status, _headers, body = described_class.new(ok_app).call(env_for)
    expect(status).to eq(200)
    expect(body).to eq([ 'ok' ])
  end

  context "when the downstream raises InvalidType (malformed media type)" do
    subject(:response) { described_class.new(raising_app).call(env_for) }

    it "answers a plain-text 406 instead of bubbling to a backtrace" do
      status, headers, body = response
      expect(status).to eq(406)
      expect(headers['Content-Type']).to eq('text/plain')
      expect(body).to eq([ "Not Acceptable\n" ])
    end

    it "logs a single terse info line naming the method and path" do
      expect(Rails.logger).to receive(:info).with(
        a_string_matching(%r{malformed media type \(406\): GET / })
      )
      response
    end
  end
end
