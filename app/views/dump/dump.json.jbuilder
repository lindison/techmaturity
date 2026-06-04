json.array!(@products) do |product|
  framework = product.framework_or_default
  assessment = product.assessments.latest.first

  json.set! :productInfo do
    json.name product.name
    json.type product.product_type
    json.framework framework&.name
    product.tags.each do |tag|
      json.set! tag.key, tag.value
    end
  end

  next unless assessment

  dimension_values = assessment.dimension_values
  capability_values = assessment.capability_values

  json.set! :categories do
    framework.dimensions.order(:position).each_with_index do |dimension, index|
      json.set! dimension.name, dimension_values[index]
    end
  end

  json.set! :capabilities do
    framework.capabilities.each_with_index do |capability, index|
      json.set! capability.name, capability_values[index]
    end
  end

  json.cloudScore assessment.total
end
