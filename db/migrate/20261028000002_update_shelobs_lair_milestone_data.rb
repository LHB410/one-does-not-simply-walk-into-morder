class UpdateShelobsLairMilestoneData < ActiveRecord::Migration[8.0]
  def up
    milestone = Milestone.find_by(name: "Shelob's Lair")
    return unless milestone

    milestone.update!(
      shop_url: "https://www.etsy.com/jp/listing/643111270/garadorieruno-xio?ls=s&ga_order=most_relevant&ga_search_type=all&ga_view_type=gallery&ga_search_query=light+of+erendil+enamel+pin&ref=sr_gallery-1-18&pro=1&content_source=f32af43e-7fee-48f7-93a8-5b57aa570a52%253ALT76a5e2619d9bd34305cc5131df39e9307b026df7&organic_search_click=1&logging_key=f32af43e-7fee-48f7-93a8-5b57aa570a52%3ALT76a5e2619d9bd34305cc5131df39e9307b026df7",
      icon_filename: "shelobs_lair.webp"
    )
  end

  def down
    milestone = Milestone.find_by(name: "Shelob's Lair")
    return unless milestone

    milestone.update!(
      shop_url: "https://www.etsy.com/search?q=shelob+spider+enamel+pin",
      icon_filename: nil
    )
  end
end
