module ApplicationHelper
  MOBILE_MAX_WIDTH_PX = 768

  def is_mobile?
    ua = request.user_agent.to_s.downcase
    return true if params[:mobile] == "1"
    ua.match?(/iphone|ipod|android.*mobile|windows phone|blackberry|bb10|opera mini|mobile safari/)
  end
end
