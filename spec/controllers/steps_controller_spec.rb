require 'rails_helper'

RSpec.describe StepsController, type: :controller do
  include_context "authenticated user"
  include_context "user with path progress"

  let(:step) { user.step }

  describe "GET #report" do
    it "returns success and renders the daily report partial" do
      DailyStepEntry.record!(user: user, path: active_path, date: Date.current, steps: 1234)

      get :report

      expect(response).to have_http_status(:ok)
      expect(response).to render_template("steps/report")
      expect(response).to render_template(partial: "steps/_daily_report")
      expect(response.body).to include("Daily Step Report")
      expect(response.body).to include("1,234")
    end
  end

  describe "PATCH #update" do
    context "when can update today" do
      before do
        allow_any_instance_of(User).to receive(:total_miles).and_return(2)
      end
      it "adds steps successfully" do
        expect {
          patch :update, params: { id: step.id, steps: 5000 }, format: :json
        }.to change { step.reload.total_steps }.by(5000)
      end

      it "returns success response" do
        patch :update, params: { id: step.id, steps: 5000 }, format: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
      end

      it "updates path progress" do
        allow_any_instance_of(User).to receive(:total_miles).and_return(400)
        allow(Path).to receive(:current).and_return(active_path)
        allow(active_path).to receive(:milestone_for_distance).and_return(rivendell)
        patch :update, params: { id: step.id, steps: 844_800 }, format: :json
        path_user.reload
        expect(path_user.current_milestone).to eq(rivendell)
        expect(path_user.progress_percentage).to eq(40.0)
      end
    end

    context "when already updated today" do
      before { step.update(last_updated_date: Date.current) }

      it "does not add steps" do
        expect {
          patch :update, params: { id: step.id, steps: 5000 }, format: :json
        }.not_to change { step.reload.total_steps }
      end

      it "returns error response" do
        patch :update, params: { id: step.id, steps: 5000 }, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to be_present
      end
    end

    context "with invalid steps" do
      it "returns error for zero steps" do
        patch :update, params: { id: step.id, steps: 0 }, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns error for negative steps" do
        patch :update, params: { id: step.id, steps: -100 }, format: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "PATCH #admin_update" do
    let(:other_user) { create(:user) }
    let(:other_step) { other_user.step }

    context "as admin" do
      include_context "authenticated admin"

      it "allows updating other users steps" do
        expect {
          patch :admin_update, params: { id: other_step.id, steps: 5000 }, format: :json
        }.to change { other_step.reload.total_steps }.by(5000)
      end

      it "returns success response" do
        patch :admin_update, params: { id: other_step.id, steps: 5000 }, format: :json

        expect(response).to have_http_status(:see_other).or have_http_status(:success)
      end
    end

    context "as non-admin" do
      it "returns forbidden" do
        patch :admin_update, params: { id: other_step.id, steps: 5000 }, format: :json

        expect(response).to have_http_status(:forbidden)
      end

      it "does not update steps" do
        expect {
          patch :admin_update, params: { id: other_step.id, steps: 5000 }, format: :json
        }.not_to change { other_step.reload.total_steps }
      end
    end
  end
end
