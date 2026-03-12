class AddShopUrlToMilestones < ActiveRecord::Migration[8.0]
  def change
    add_column :milestones, :shop_url, :string
  end
end
