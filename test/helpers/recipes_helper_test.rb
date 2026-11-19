require "test_helper"

class RecipesHelperTest < ActionView::TestCase
  test "describes durations in days, hours, and minutes" do
    assert_equal "45 min", duration_in_words(45.minutes)
    assert_equal "1 hr 30 min", duration_in_words(90.minutes)
    assert_equal "2 hr", duration_in_words(2.hours)
    assert_equal "1 day 2 hr 5 min", duration_in_words(1.day + 2.hours + 5.minutes)
    assert_equal "2 days", duration_in_words(2.days)
    assert_equal "0 min", duration_in_words(0.minutes)
    assert_nil duration_in_words(nil)
  end

  test "shows N/A for blank values" do
    assert_equal "N/A", value_or_not_available(nil)
    assert_equal "N/A", value_or_not_available("")
    assert_equal "6 servings", value_or_not_available("6 servings")
  end
end
