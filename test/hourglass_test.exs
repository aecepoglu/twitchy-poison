defmodule HourglassTest do
  use ExUnit.Case

  defp setup_need_for_break() do
    Hourglass.make(duration: 1, trend: 5)
    |> Hourglass.tick()
    |> Hourglass.tick()
  end

  test "make" do
    {past, cur} = Hourglass.make(duration: 13, trend: 17)
    assert 17 == length(past.buf |> Map.keys())
    assert cur.dur == 13
  end

  test "keeping record of time passing by" do
    trend =
      Hourglass.make(duration: 1, trend: 5)
      |> Hourglass.progress(3)
      |> Hourglass.tick()
      |> Hourglass.progress(4)
      |> Hourglass.tick()
      |> elem(0)
      |> Trend.to_list()

    assert [4, 3, -1, -1, -1] == trend
  end

  test "staying idle too is a cause for an alarm" do
    right =
      setup_need_for_break()
      |> Hourglass.alerts

    alarm = %Alarm{
      id: "idle",
      label: "split your task",
      type: :countdown,
      snooze: 15,
      val: 0}
    assert [alarm] == right
  end

  test "taking a break rids of the need for break" do
    right =
      setup_need_for_break()
      |> Hourglass.switch_mode(:break)
      |> Hourglass.tick
      |> Hourglass.alerts

    assert [] == right
  end
end
