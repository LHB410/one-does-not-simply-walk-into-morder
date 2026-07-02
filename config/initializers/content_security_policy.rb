# Be sure to restart your server when you modify this file.

# Application-wide Content Security Policy (ASVS V14 defense-in-depth against XSS).
# https://guides.rubyonrails.org/security.html#content-security-policy-header
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data
    policy.img_src     :self, :data
    policy.object_src  :none
    # 'self' covers Stimulus/Turbo + the vendored panzoom; the importmap inline
    # tags are allowed via the per-request nonce below. No external script hosts.
    policy.script_src  :self
    # Inline styles: Turbo's injected progress bar + a handful of style="" attrs.
    policy.style_src   :self, :unsafe_inline
    policy.base_uri    :self
    policy.form_action :self
    policy.frame_ancestors :self
  end

  # Nonce the inline importmap/module scripts. Per-request random keeps it
  # non-empty on logged-out pages (an empty nonce would block the import map).
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  # script-src only — a nonce on style-src would disable the 'unsafe-inline' above.
  config.content_security_policy_nonce_directives = %w[script-src]
end
