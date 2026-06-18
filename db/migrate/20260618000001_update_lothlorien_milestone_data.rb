class UpdateLothlorienMilestoneData < ActiveRecord::Migration[8.0]
  def up
    milestone = Milestone.find_by(name: "Lothlórien")
    return unless milestone

    milestone.update!(
      shop_url: "https://www.etsy.com/listing/4464139506/leaf-of-lorien-v1-25-enamel-pin?ls=s&ga_order=most_relevant&ga_search_type=all&ga_view_type=gallery&ga_search_query=lorien+enamel+pin&ref=sr_gallery-1-12&sts=1&content_source=06959dee-98d7-4c51-9a2e-0d1c92dbf04e%253ALT3c992c363c341116b488ca4cc3a9c796e8d91f26&organic_search_click=1&logging_key=06959dee-98d7-4c51-9a2e-0d1c92dbf04e%3ALT3c992c363c341116b488ca4cc3a9c796e8d91f26",
      icon_filename: "lothlorien.svg"
    )
  end

  def down
    milestone = Milestone.find_by(name: "Lothlórien")
    return unless milestone

    milestone.update!(
      shop_url: "https://www.etsy.com/search?q=lothlorien+enamel+pin",
      icon_filename: nil
    )
  end
end
