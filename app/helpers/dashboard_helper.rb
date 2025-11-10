# app/helpers/dashboard_helper.rb
module DashboardHelper
  def path_coordinates(path)
    # Generate SVG path from milestone coordinates
    return "" unless path&.milestones&.any?

    points = path.milestones.map do |m|
      "#{m.map_position_x},#{m.map_position_y}"
    end

    # Create a smooth curved path
    "M #{points.join(' L ')}"
  end

  def calculate_token_position(path_user, path)
    return { x: 10, y: 80 } unless path_user&.current_milestone

    current_milestone = path_user.current_milestone
    next_milestone = path.next_milestone_after(current_milestone)

    if next_milestone && path_user.progress_percentage < 100
      # Interpolate between current and next milestone
      user_miles = path_user.user.total_miles
      miles_from_current = user_miles - current_milestone.cumulative_distance_miles
      miles_to_next = next_milestone.cumulative_distance_miles - current_milestone.cumulative_distance_miles

      progress_fraction = miles_to_next > 0 ? (miles_from_current / miles_to_next.to_f) : 0

      x = current_milestone.map_position_x +
          (next_milestone.map_position_x - current_milestone.map_position_x) * progress_fraction
      y = current_milestone.map_position_y +
          (next_milestone.map_position_y - current_milestone.map_position_y) * progress_fraction

      { x: x, y: y }
    else
      # At milestone
      {
        x: current_milestone.map_position_x,
        y: current_milestone.map_position_y
      }
    end
  end
end
