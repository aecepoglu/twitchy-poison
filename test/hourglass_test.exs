defmodule HourglassTest do
  alias Progress.Hourglass, as: Hourglass
  alias Progress.Trend, as: Trend

  use ExUnit.Case

  defp setup_need_for_break() do
    Hourglass.make(duration: 1, trend: 5)
    |> Hourglass.tick(:work)
    |> Hourglass.tick(:work)
    |> Hourglass.tick(:work)
    |> Hourglass.tick(:work)
  end

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

  test "staying idle is a cause for an alarm" do
    alerts =
      setup_need_for_break()
      |> Hourglass.alerts

    assert alerts == [%Alarm{
      id: "idle",
      label: "split your task",
      type: :countdown,
      snooze: 15,
      later: 0}]
  end

  test "having taken a break removes the need for break" do
    alerts =
      setup_need_for_break()
      |> Hourglass.tick(:break)
      |> Hourglass.alerts

    assert alerts == []
  end

  defp log_activity(hourglass, mode, [times: k, progress: p]) do
    Enum.reduce(1..k, hourglass,
      fn _, hg ->
        hg
        |> Hourglass.progress(p)
        |> Hourglass.tick(mode)
      end)
  end

  test "working a lot is a cause for an alarm" do
    alerts = Hourglass.make(duration: 1)
    |> log_activity(:work, times: 10, progress: 1)
    |> Hourglass.alerts()

    assert alerts == [Alarm.make("rest", label: "take a break")]
  end
end
