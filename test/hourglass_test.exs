defmodule HourglassTest do
  use ExUnit.Case

  defp setup_need_for_break() do
    Hourglass.make(duration: 1, trend: 5)
    |> Hourglass.tick()
    |> Hourglass.tick()
  end

  test "make" do
    {past, cur, future} = Hourglass.make(duration: 13, trend: 17)
    assert 17 == length(past.buf |> Map.keys())
    assert cur.dur == 13
    assert [] == future
  end

  test "no breaks suggested at the start" do
    right =
      Hourglass.make(duration: 1, trend: 5)
      |> Hourglass.list_alarms()

    assert [] == right
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

  @tag :wip
  test "staying idle too is a cause for an alarm" do
    right =
      setup_need_for_break()
      |> Hourglass.list_alarms()

    assert [%Alarm{label: "split your task", type: :countdown, snooze: 0, val: 0}] == right
  end

  test "taking a break rids of the need for break" do
    right =
      setup_need_for_break()
      |> then(fn {a, b, _} -> {a, b, []} end)
      |> Hourglass.switch_mode(:break)
      |> Hourglass.tick()
      |> Hourglass.list_alarms()

    assert [] == right
  end

  test "add_alarm()" do
    right =
      Hourglass.make()
      |> Hourglass.add_alarm(Alarm.make(:countdown, 1, 100, "twenty seconds"))
      |> Hourglass.tick()
      |> Hourglass.list_alarms()

    assert [Alarm.make(:countdown, 0, 100, "twenty seconds")] == right
  end

  @tag :skip
  test "popups 1" do
    # popup shown suggesting a break
    # snooze
    # popup disappears
    # alarm is re-queued
  end

  @tag :skip
  test "popups 2" do
    # popup shown suggesting a break
    # OK
    # popup disappears
    # mode is switched to break
  end
end
