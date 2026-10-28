class UpdateDeadMarshesMilestoneData < ActiveRecord::Migration[8.0]
  def up
    milestone = Milestone.find_by(name: "Dead Marshes")
    return unless milestone

    milestone.update!(
      shop_url: "https://www.etsy.com/jp/listing/4304794439/mo-nno-wangdisento-hdoenamerupintosutekk?ls=s&ga_order=most_relevant&ga_search_type=all&ga_view_type=gallery&ga_search_query=dead+marshes+lord+of+the+rings+enamel+pin&ref=sr_gallery-1-38&content_source=9421de4c-3258-47dd-858f-a9e0aa672eba%253ALT29d30121c1ced41d9c611734acaf078a7506e43b&organic_search_click=1&logging_key=9421de4c-3258-47dd-858f-a9e0aa672eba%3ALT29d30121c1ced41d9c611734acaf078a7506e43b",
      icon_filename: "dead_marshes.webp"
    )
  end

  def down
    milestone = Milestone.find_by(name: "Dead Marshes")
    return unless milestone

    milestone.update!(
      shop_url: "https://www.etsy.com/search?q=dead+marshes+lord+of+the+rings+pin",
      icon_filename: nil
    )
  end
end
