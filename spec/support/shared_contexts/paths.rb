RSpec.shared_context "active path with milestones" do
  let!(:active_path) do
    create(:path, :active, part_number: 1, total_distance_miles: 1000)
  end

  let!(:shire) do
    create(:milestone,
      path: active_path,
      name: "Shire",
      distance_from_previous_miles: 0,
      cumulative_distance_miles: 0,
      sequence_order: 0,
      map_position_x: 10,
      map_position_y: 80
    )
  end

  let!(:rivendell) do
    create(:milestone,
      path: active_path,
      name: "Rivendell",
      distance_from_previous_miles: 400,
      cumulative_distance_miles: 400,
      sequence_order: 1,
      map_position_x: 25,
      map_position_y: 60
    )
  end

  let!(:mordor) do
    create(:milestone,
      path: active_path,
      name: "Mount Doom",
      distance_from_previous_miles: 600,
      cumulative_distance_miles: 1000,
      sequence_order: 2,
      map_position_x: 90,
      map_position_y: 20
    )
  end
end

RSpec.shared_context "user with path progress" do
  include_context "active path with milestones"

  let(:user) { create(:user) }
  let!(:path_user) do
    create(:path_user,
      user: user,
      path: active_path,
      current_milestone: shire,
      progress_percentage: 0.0
    )
  end
end


