require 'rails_helper'

RSpec.describe RegistrationsController, type: :controller do
  render_views

  describe "GET #new" do
    context "as a visitor" do
      before { session[:user_id] = nil }

      it "renders the sign-up form" do
        get :new

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Form Your Fellowship")
      end
    end

    context "when already logged in" do
      include_context "authenticated user"

      it "redirects to root" do
        get :new

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "POST #create" do
    let(:valid_params) do
      {
        registration: {
          group_name: "The Fellowship",
          group_password: "speak-friend",
          group_password_confirmation: "speak-friend",
          leader_name: "Frodo",
          leader_email: "frodo@shire.me",
          members: [
            { name: "Sam", email: "sam@shire.me" },
            { name: "Merry", email: "merry@buckland.me" }
          ]
        }
      }
    end

    context "with valid input" do
      it "creates one group" do
        expect { post :create, params: valid_params }.to change(Group, :count).by(1)
      end

      it "creates the leader plus all members" do
        expect { post :create, params: valid_params }.to change(User, :count).by(3)
      end

      it "assigns the leader to the group and links all members" do
        post :create, params: valid_params
        group = Group.last

        expect(group.leader.email).to eq("frodo@shire.me")
        expect(group.users.pluck(:email)).to contain_exactly(
          "frodo@shire.me", "sam@shire.me", "merry@buckland.me"
        )
      end

      it "gives every member a step and a token color (no member left without a Step)" do
        post :create, params: valid_params
        group = Group.last

        expect(group.users.all? { |u| u.step.present? }).to be true
        expect(group.users.all? { |u| u.token_color.present? }).to be true
      end

      it "logs the leader in" do
        post :create, params: valid_params

        expect(session[:user_id]).to eq(Group.last.leader.id)
      end

      it "lets a member authenticate with the shared group password afterward" do
        post :create, params: valid_params
        member = User.find_by(email: "sam@shire.me")

        expect(member.group.authenticate("speak-friend")).to eq(member.group)
      end

      it "ignores blank member rows" do
        params_with_blank = valid_params.deep_dup
        params_with_blank[:registration][:members] << { name: "", email: "" }

        expect { post :create, params: params_with_blank }.to change(User, :count).by(3)
      end
    end

    context "with an active path" do
      include_context "active path with milestones"

      before { allow(Path).to receive(:current).and_return(active_path) }

      it "places the leader and every member on the path so they appear on the map" do
        post :create, params: valid_params
        group = Group.last

        expect(group.users.count).to eq(3)
        group.users.each do |member|
          position = member.path_users.find_by(path: active_path)
          expect(position).to be_present
          expect(position.current_milestone).to eq(shire)
        end
      end
    end

    context "with invalid input" do
      it "rolls back fully when the group password is too short" do
        bad = valid_params.deep_dup
        bad[:registration][:group_password] = "short"
        bad[:registration][:group_password_confirmation] = "short"

        expect { post :create, params: bad }.not_to change { [ Group.count, User.count ] }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "rolls back fully when a member email duplicates an existing user" do
        create(:user, email: "sam@shire.me")

        expect { post :create, params: valid_params }.not_to change { [ Group.count, User.count ] }
      end

      it "rolls back fully when the password confirmation does not match" do
        bad = valid_params.deep_dup
        bad[:registration][:group_password_confirmation] = "mismatch"

        expect { post :create, params: bad }.not_to change { [ Group.count, User.count ] }
      end
    end
  end
end
