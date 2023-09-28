defmodule TrendTest do
  use ExUnit.Case
  alias Progress.Trend, as: Trend
  alias Progress.CurWin, as: CurWin

  @idle nil

  test "Trend.make initial state" do
    trend = Trend.make(3)
    |> Trend.to_list()
    assert trend == [ @idle, @idle, @idle ]
  end

  test "Trend.add sanitises the input" do
    elems = Trend.make(3)
    |> Trend.add(%CurWin{done: 13}) |> elem(0)
    |> Trend.to_list
    assert elems == [{8, 0}, @idle, @idle]
  end

  test "Trend.add rolls around, keeping the last $size" do
    trend = Trend.make(3)
    |> Trend.add(%CurWin{done: 1, broke: 3}) |> elem(0)
    |> Trend.add(%CurWin{done: 2, broke: 4}) |> elem(0)
    |> Trend.add(%CurWin{done: 3, broke: 1}) |> elem(0)
    |> Trend.add(%CurWin{done: 4, broke: 0}) |> elem(0)
    |> Trend.add(%CurWin{done: 5, broke: 3}) |> elem(0)
    |> Trend.to_list

    assert trend == [{5, 3}, {4, 0}, {3, 1}]
  end

  test "Trend stats give sums of each" do
    trend = Trend.make(3)
    |> Trend.add(%CurWin{done: 1, broke: 3}) |> elem(0)
    |> Trend.add(%CurWin{done: 2, broke: 4}) |> elem(0)
    |> Trend.add(%CurWin{done: 3, broke: 1}) |> elem(0)
    |> Trend.add(%CurWin{done: 4, broke: 0}) |> elem(0)
    |> Trend.add(%CurWin{done: 5, broke: 3}) |> elem(0)
    |> Trend.stats

    assert trend == {12, 4}
  end

  test "stores work and the breaks" do
    win =
      CurWin.make(8)
      |> CurWin.tick(:work, 4)
      |> CurWin.work(3)
      |> CurWin.tick(:break, 2)

    trend =
      Trend.make(5)
      |> Trend.add(win) |> elem(0)
      |> Trend.to_list()

    assert trend == [{3, 2}, @idle, @idle, @idle, @idle]
  end

  test "adding carries over extra stuff" do
    now = CurWin.make(8) |> CurWin.work(19)
    trend = Trend.make(5)
    {trend, now} = Trend.add(trend, now)
    {trend, now} = Trend.add(trend, now)
    {trend, now} = Trend.add(trend, now)
    {trend, now} = Trend.add(trend, now)
    {trend, _  } = Trend.add(trend, now)
    assert Trend.to_list(trend) == [{0, 0}, {0, 0}, {3, 0}, {8, 0}, {8, 0}]
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
