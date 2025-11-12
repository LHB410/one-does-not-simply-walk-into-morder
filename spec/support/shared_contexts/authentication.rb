RSpec.shared_context "authenticated user" do
  let(:user) { create(:user) }

  before do
    session[:user_id] = user.id
  end
end

RSpec.shared_context "authenticated admin" do
  let(:admin) { create(:user, :admin) }

  before do
    session[:user_id] = admin.id
  end
end
