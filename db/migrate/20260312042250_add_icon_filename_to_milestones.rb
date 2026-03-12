class AddIconFilenameToMilestones < ActiveRecord::Migration[8.0]
  def change
    add_column :milestones, :icon_filename, :string
  end
end
