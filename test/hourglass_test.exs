defmodule HourglassTest do
  alias Progress.Hourglass, as: Hourglass
  alias Progress.Trend, as: Trend

  use ExUnit.Case

  test "make" do
    {past, cur} = Hourglass.make(duration: 13, trend: 17)
    assert Trend.size(past) == 0
    assert cur.dur == 13
  end

  test "keeping record of time passing by" do
    trend =
      Hourglass.make(duration: 1, trend: 5)
      |> Hourglass.progress(3)
      |> Hourglass.tick(:work)
      |> Hourglass.progress(4)
      |> Hourglass.tick(:work)
      |> Hourglass.past
      |> Trend.to_list
    assert trend == [{:work, 4}, {:work, 3}]
  end
end
