defmodule ModelTest do
  use ExUnit.Case

  defp times(x0, n, f) do
    Enum.reduce(1..n, x0, fn _, xN -> f.(xN) end)
  end

  test "taking a break gets rid of the break reminder" do
    upcoming = Upcoming.empty()
      |> Upcoming.add(Popup.Known.rest(), 60)

    m = %Model{}
        |> Map.put(:upcoming, upcoming)
        |> Model.update({:mode, :break})

    assert m.upcoming == Upcoming.empty()
  end

  test "returning to work after a break creates a break reminder" do
    m = %Model{}
    |> Map.put(:mode, :break)
    |> Map.put(:upcoming, Upcoming.empty())
    |> times(7, & Model.update(&1, :tick))
    |> Model.update({:mode, :work})

    assert m.upcoming ==
      Upcoming.empty
      |> Upcoming.add(Popup.Known.rest(), 21)
  end

  test "time spent while in meeting is logged as work" do
      %{work: worked} =
        %Model{}
        |> Model.update({:mode, :meeting})
        |> Model.update(:tick)
        |> Map.get(:hg)
        |> Progress.Hourglass.past()
        |> Progress.Trend.stats()

    assert worked == 1
  end

  test "be reminded to populate stuff in the beginning" do
    _popups = %Model{}
    |> Map.fetch!(:popups)
    assert match?(_popups, [
      %Popup{label: "create some tasks"},
      %Popup{label: "create some chores"},
    ])
  end

  test "pack the goal together with the done tasks" do
    m = %Model{}
    |> Model.update({:goal, :set, "my goal"})
    |> Model.update([:task, :add, "task 1", :last])
    |> Model.update([:task, :add, "task 2", :last])
    |> Model.update([:task, :add, "task 3", :last])
    |> Model.update([:task, :join])
    |> Model.update([:task, :done])
    |> Model.update([:task, :done])
    |> Model.update({:goal, :envelop})

    assert m.goal == Goal.empty()

    assert m.todo == Todo.empty()
    |> Todo.add(%Todo{label: "my goal"}, :last)
    |> Todo.add(%Todo{label: "task 1"}, :last)
    |> Todo.add(%Todo{label: "task 2"}, :last)
    |> Todo.join_eager()
    |> Todo.add(%Todo{label: "task 3"}, :last)
    |> Todo.mark_done!()
    |> Todo.mark_done!()
    |> Todo.mark_done!()
  end

  test "stay idle, see popup, snooze it, wait, see it again" do
    m0 = %Model{} |> Map.put(:upcoming, Upcoming.empty())

    model = Enum.reduce(1..90, m0, fn _, acc ->
      acc
      |> Model.update(:tick)
    end)
    assert model.upcoming == []
    assert model.popups == [Popup.Known.idle()]

    model = model |> Model.update({:key, "s"})
    assert model.popups == []
    assert length(model.upcoming) == 1

    model = model
    |> Model.update(:tick)
    |> Model.update(:tick)
    |> Model.update(:tick)
    |> Model.update(:tick)
    |> Model.update(:tick)

    assert model.upcoming == []
    assert model.popups == [Popup.Known.idle()]
  end
end
