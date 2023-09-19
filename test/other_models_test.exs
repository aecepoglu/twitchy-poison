defmodule CurWinTest do
  use ExUnit.Case

  test "CurWin.progress" do
    right =
      CurWin.make(7)
      |> CurWin.work(3)
      |> CurWin.tick(:break, 5)
      |> elem(0)

    assert %CurWin{val: 5, done: 3, broke: 5, dur: 7} == right
  end
end

defmodule TrendTest do
  use ExUnit.Case

  test "Trend.make initial state" do
    assert [-1, -1, -1] == Trend.make(3) |> Trend.to_list()
  end

  test "Trend.add keeps last N" do
    right =
      100..107
      |> Enum.map(fn x -> %CurWin{done: x} end)
      |> Enum.reduce(Trend.make(5), fn x, a -> Trend.add(a, x) end)
      |> Trend.to_list()

    assert [107, 106, 105, 104, 103] == right
  end

  test "if mostly did work, then Trend will show it" do
    win =
      CurWin.make(8)
      |> CurWin.tick(:work, 4) |> elem(0)
      |> CurWin.work(3)
      |> CurWin.tick(:break, 2) |> elem(0)

    right =
      Trend.make(5)
      |> Trend.add(win)
      |> Trend.to_list()

    assert [3, -1, -1, -1, -1] == right
  end
end
