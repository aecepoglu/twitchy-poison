defmodule FlowStateTest do
  use ExUnit.Case
  setup_all  do
    %{model: %Model{
      hg: Progress.Hourglass.make()
    }}
  end 

  test "break suggestions should take into account only the time spent since last break", %{model: m} do
    ops =[:work,:work,:work,:work, :idle,:idle,:idle, :break]
    Enum.any?(1..32, fn _ ->
      activity = Enum.map(1..10, fn _ -> Enum.random([:work, :idle]) end) # TODO 32 -> 1024

      m1 = m
      |> log_activity(Enum.map(1..32, fn _ -> Enum.random(ops) end))
      |> log_activity([:break])
      |> log_activity(activity)

      m2 = m
      |> log_activity(activity)

      [p1, p2] = [m1, m2] |> Enum.map(&FlowState.alarms/1)

      if p1 != p2 do
        IO.puts(Progress.Hourglass.string(m1.hg, :work, {50, 1}))
        IO.puts(Progress.Hourglass.string(m2.hg, :work, {50, 1}))
        assert p1 == p2
        false
      else
        true
      end
    end)
  end

  @idle_activity [:idle, :idle, :idle]

  test "suggest splitting a task if I'm stuck", %{model: m} do
    _popups = m
    |> log_activity(@idle_activity)
    |> FlowState.alarms

    assert match?(_popups, [%Popup{label: "split your task"}])
  end

  test "I'm not stuck if I've pushed in some work", %{model: m} do
    popups = m
    |> log_activity(@idle_activity ++ [:work])
    |> FlowState.alarms

    assert popups == []
  end

  test "I'm not stuck if I've attempted some work", %{model: m} do
    popups = m
    |> log_activity(@idle_activity)
    |> Map.update!(:hg, &Progress.Hourglass.progress(&1, :small))
    |> FlowState.alarms

    assert popups == []
  end

  test "delay suggesting breaks if I'm very well focused", %{model: m} do
    popups = m
    |> log_activity(Enum.map(1..10, fn _ -> :work end))
    |> FlowState.alarms

    assert popups == []
  end

  test "don't suggest a break if I've already declined the offer", %{model: m} do
    upcoming = Upcoming.empty() |> Upcoming.add(Popup.make(:idle, "...", snooze: 15))
    popups = %{m | upcoming: upcoming}
    |> log_activity(@idle_activity)
    |> FlowState.alarms

    assert popups == []
  end

  defp log_activity(%Model{hg: hg0}=m, activity) do
    alias Progress.Hourglass, as: Hg
    hg = Enum.reduce(activity, hg0, fn op, hg ->
      case op do
        :work  -> hg |> Hg.progress(:small) |> Hg.tick(:work)
        :idle  -> hg |> Hg.tick(:work)
        :break -> hg |> Hg.tick(:break)
      end
    end)
    %{m | hg: hg}
  end
end
