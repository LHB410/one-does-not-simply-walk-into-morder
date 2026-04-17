class UpdateMoriaMilestoneData < ActiveRecord::Migration[8.0]
  def up
    milestone = Milestone.find_by(name: "Moria")
    return unless milestone

    milestone.update!(
      shop_url: "https://www.etsy.com/listing/876601286/gates-of-moria-antique-silver-enamel-pin?ls=s&ga_order=most_relevant&ga_search_type=all&ga_view_type=gallery&ga_search_query=moria+pin&ref=sr_gallery-1-8&organic_search_click=1&sts=1&content_source=3d66dcb4-19c4-4d34-b4aa-551b4fdb7b6a%253ALTae3bb7dce55a78f0e1a278421bc4846d9938094c&logging_key=3d66dcb4-19c4-4d34-b4aa-551b4fdb7b6a%3ALTae3bb7dce55a78f0e1a278421bc4846d9938094c&variation0=4142732506",
      icon_filename: "moria.svg"
    )
  end

  def down
    milestone = Milestone.find_by(name: "Moria")
    return unless milestone

    milestone.update!(
      shop_url: "https://www.etsy.com/search?q=moria+mines+enamel+pin",
      icon_filename: nil
    )
  end
end
