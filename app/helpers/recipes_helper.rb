module RecipesHelper
  def value_or_not_available(value)
    value.presence || t("recipes.not_available")
  end

  # 4500 seconds reads as "1 hr 15 min".
  def duration_in_words(duration)
    return if duration.nil?

    days, remainder = duration.to_i.divmod(1.day.to_i)
    hours, remainder = remainder.divmod(1.hour.to_i)
    minutes = remainder / 1.minute.to_i
    parts = { days:, hours:, minutes: }.filter_map { |unit, count| t("recipes.duration.#{unit}", count:) if count.positive? }
    parts.presence&.to_sentence(words_connector: " ", two_words_connector: " ", last_word_connector: " ") || t("recipes.duration.minutes", count: 0)
  end
end
