defmodule HourglassTest do
  use ExUnit.Case

  defp setup_need_for_break() do
    Hourglass.make(duration: 1, trend: 5)
    |> Hourglass.tick(:work)
    |> Hourglass.tick(:work)
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
      |> Hourglass.tick(:work)
      |> Hourglass.progress(4)
      |> Hourglass.tick(:work)
      |> elem(0)
      |> Trend.to_list()
    assert [{4, 0}, {3, 0}, nil, nil, nil] == trend
  end

  test "staying idle is a cause for an alarm" do
    right =
      setup_need_for_break()
      |> Hourglass.alerts

    alarm = %Alarm{
      id: "idle",
      label: "split your task",
      type: :countdown,
      snooze: 15,
      later: 0}
    assert [alarm] == right
  end

  test "having taken a break removes the need for break" do
    right =
      setup_need_for_break()
      |> Hourglass.tick(:break)
      |> Hourglass.alerts

    assert [] == right
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
