# config/initializers/simple_form_tailwind.rb
SimpleForm.setup do |config|
  config.wrappers :tailwind, tag: "div", class: "mb-4", error_class: "error" do |b|
    b.use :html5
    b.use :placeholder
    b.optional :maxlength
    b.optional :minlength
    b.optional :pattern
    b.optional :min_max
    b.optional :readonly
    b.use :label, class: "block text-sm font-medium text-gray-300 mb-1"
    b.use :input, class: "w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-md text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-yellow-500", error_class: "border-red-500"
    b.use :error, wrap_with: { tag: "p", class: "text-red-400 text-xs mt-1" }
    b.use :hint, wrap_with: { tag: "p", class: "text-gray-500 text-xs mt-1" }
  end

  config.default_wrapper = :tailwind
  config.button_class = "w-full py-2 px-4 bg-yellow-600 hover:bg-yellow-700 text-stone-900 font-bold rounded-md transition-colors duration-200 cursor-pointer"
  config.error_notification_tag = :div
  config.error_notification_class = "bg-red-900 border border-red-600 text-red-200 px-4 py-3 rounded mb-4"
end
