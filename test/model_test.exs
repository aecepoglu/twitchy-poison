defmodule ModelTest do
  use ExUnit.Case

  test "time spent while in meeting is logged as work" do
    %Model{ hg: {_, now} } =
      %Model{}
      |> Model.update([:task, :add, "@meeting w/ someone important", :next])
      |> Model.update(:tick_minute)
    assert now.done > 0
  end

  test "be reminded to populate stuff in the beginning" do
    _popups = %Model{}
    |> Map.fetch!(:popups)
    assert match?(_popups, [
      %Popup{label: "create some tasks"},
      %Popup{label: "create some chores"},
    ])
  end

  test "stay idle, see popup, snooze it, wait, see it again" do
    m0 = %Model{}
    model = Enum.reduce(1..50, m0, fn _, acc ->
      acc
      |> Model.update(:tick_minute)
    end)
    assert model.popups == [Popup.make(:idle, "split your task", snooze: 5)]
    assert model.upcoming == []

    model = model |> Model.update(:action_1)
    assert model.popups == []
    assert length(model.upcoming) == 1

    model = model
    |> Model.update(:tick_minute)
    |> Model.update(:tick_minute)
    |> Model.update(:tick_minute)
    |> Model.update(:tick_minute)
    |> Model.update(:tick_minute)

    assert model.popups == [Popup.make(:idle, "split your task", snooze: 5)]
    assert model.upcoming == []
  end
end

defmodule FlowStateTest do
  use ExUnit.Case
  setup_all  do
    %{model: %Model{
      hg: Progress.Hourglass.make(duration: 1)
    }}
  end 

  test "suggest a break if I've worked long enough", %{model: m} do
    ops = [:work, :idle]
    Enum.each(1..32, fn _ ->
      _popups = m

      |> log_activity(Enum.map(1..10, fn _ -> Enum.random(ops)  end))
      |> FlowState.alarms

      assert match?(_popups, [%Popup{label: "take a break"}])
    end)
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
        IO.puts(Progress.Hourglass.string(m1.hg, {50, 1}))
        IO.puts(Progress.Hourglass.string(m2.hg, {50, 1}))
        assert p1 == p2
        false
      else
        true
      end
    end)
  end

  test "suggest splitting a task if I'm stuck", %{model: m} do
    _popups = m
    |> log_activity([:idle, :idle, :idle])
    |> FlowState.alarms

    assert match?(_popups, [%Popup{label: "split your task"}])
  end

  test "delay suggesting breaks if I'm very well focused", %{model: m} do
    popups = m
    |> log_activity(Enum.map(1..10, fn _ -> :work end))
    |> FlowState.alarms

    assert popups == []
  end

  @tag :wip
  test "don't suggest a break if I've already declined the offer", %{model: m} do
    upcoming = Upcoming.empty() |> Upcoming.add(Popup.make(:idle, "...", snooze: 15))
    popups = %{m | upcoming: upcoming}
    |> log_activity([:idle, :idle, :idle])
    |> FlowState.alarms

    assert popups == []
  end

  defp log_activity(%Model{hg: hg0}=m, activity) do
    alias Progress.Hourglass, as: Hg
    hg = Enum.reduce(activity, hg0, fn op, hg ->
      case op do
        :work  -> hg |> Hg.progress(1) |> Hg.tick(:work)
        :idle  -> hg |> Hg.tick(:work)
        :break -> hg |> Hg.tick(:break)
      end
    end)
    %{m | hg: hg}
  end
end
