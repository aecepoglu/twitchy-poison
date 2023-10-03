defmodule TrendTest do
  use ExUnit.Case
  alias Progress.Trend, as: Trend
  alias Progress.CurWin, as: CurWin

  test "Trend.add sanitises the input" do
    elems = Trend.make(3)
    |> Trend.add(%CurWin{done: 13})
    |> Trend.to_list
    assert elems == [{:work, 8}]
  end

  test "Trend.add propagates the update" do
    elems = Trend.make(3)
    |> Trend.add(%CurWin{})
    |> Trend.add(%CurWin{})
    |> Trend.add(%CurWin{})
    |> Trend.add(%CurWin{})
    |> Trend.add(%CurWin{done: 19, broke: 0})
    |> Trend.to_list
    assert elems == [{:work, 8}, {:work, 8}, {:work, 3}, :idle, :idle]
  end

  test "Trend.add propagates the update after applying the non-work portion" do
    elems = Trend.make(3)
    |> Trend.add(%CurWin{})
    |> Trend.add(%CurWin{})
    |> Trend.add(%CurWin{})
    |> Trend.add(%CurWin{})
    |> Trend.add(%CurWin{done: 19, broke: 99})
    |> Trend.to_list
    assert elems == [:break, {:work, 8}, {:work, 3}, :idle, :idle]
  end

  test "Trend stats give sums of each" do
    trend = Trend.make(3)
    |> Trend.add(%CurWin{done: 1, broke: 3})
    |> Trend.add(%CurWin{done: 0, broke: 0})
    |> Trend.add(%CurWin{done: 3, broke: 1})
    |> Trend.add(%CurWin{done: 4, broke: 0})
    |> Trend.add(%CurWin{done: 5, broke: 3})
    |> Trend.stats

    assert trend == %{work: 1, idle: 1, break: 3}
  end

  test "count stats up until the very beginning" do
    1..50
    |> Enum.each(fn _ -> parametrised_test() end)
  end
  defp parametrised_test() do
    idle = CurWin.make(2)
    work =  idle |> CurWin.work(1)
    break = idle |> CurWin.tick(:break)
    activities = %{idle: idle, work: work, break: break}

    len = Enum.random(5..15)
    trend = Trend.make(len)
    activity = 1..len
             |> Enum.map(fn _ -> Enum.random([:idle, :work, :break]) end)
    stats = activity
    |> Enum.map(& activities[&1])
    |> Enum.reduce(trend, &Trend.add(&2, &1))
    |> Trend.stats

    expected = Map.merge(
      %{work: 0, break: 0, idle: 0},
      activity |> Enum.reverse
               |> Enum.take(len)
               |> Enum.frequencies())
    assert stats == expected
  end
end

defmodule CurWinTest do
  alias Progress.CurWin, as: CurWin
  use ExUnit.Case

  test "CurWin.progress" do
    cw =
      CurWin.make(7)
      |> CurWin.work(3)
      |> CurWin.tick(:break, 5)

    assert cw == %CurWin{val: 5, done: 3, broke: 5, dur: 7}
  end
end
