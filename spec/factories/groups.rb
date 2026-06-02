FactoryBot.define do
  factory :group do
    sequence(:name) { |n| "Fellowship #{n}" }
    password { "speak-friend" }
    password_confirmation { "speak-friend" }
  end
end
