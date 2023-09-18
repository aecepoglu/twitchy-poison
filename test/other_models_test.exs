defmodule CurWinTest do
  use ExUnit.Case

  test "CurWin.progress :work" do
    right =
      CurWin.make(7)
      |> CurWin.progress(3)
      |> CurWin.switch(:break)
      |> CurWin.progress(5)

    assert %CurWin{mode: :break, done: 3, broke: 5, dur: 7} == right
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

  test "Trend.add mostly work adds break if currently on break" do
    win =
      CurWin.make(8)
      |> CurWin.tick(4)
      |> elem(0)
      |> CurWin.progress(3)
      |> CurWin.switch(:break)
      |> CurWin.progress(2)

    right =
      Trend.make(5)
      |> Trend.add(win)
      |> Trend.to_list()

    assert [-1, -1, -1, -1, -1] == right
  end
end
