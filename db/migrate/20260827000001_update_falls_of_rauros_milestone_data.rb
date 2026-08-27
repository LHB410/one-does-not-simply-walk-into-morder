class UpdateFallsOfRaurosMilestoneData < ActiveRecord::Migration[8.0]
  def up
    milestone = Milestone.find_by(name: "Falls of Rauros")
    return unless milestone

    milestone.update!(
      shop_url: "https://www.etsy.com/jp/listing/1526219344/bgurdoboromiashrudohdoenamerupin?ls=s&ga_order=most_relevant&ga_search_type=all&ga_view_type=gallery&ga_search_query=boromir+pin&ref=sr_gallery-1-1&sts=1&content_source=0061e3b9-fc17-48fc-8418-6141fa60868e%253ALT2d5713fbdfd95c552ba004075af936f33eb50d6c&organic_search_click=1&logging_key=0061e3b9-fc17-48fc-8418-6141fa60868e%3ALT2d5713fbdfd95c552ba004075af936f33eb50d6c",
      icon_filename: "falls_of_rauros.svg"
    )
  end

  def down
    milestone = Milestone.find_by(name: "Falls of Rauros")
    return unless milestone

    milestone.update!(
      shop_url: "https://www.etsy.com/search?q=falls+of+rauros+pin",
      icon_filename: nil
    )
  end
end
