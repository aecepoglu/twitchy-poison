defmodule CurWinTest do
  use ExUnit.Case

  test "CurWin.progress" do
    right =
      CurWin.make(7)
      |> CurWin.work(3)
      |> CurWin.tick(:break, 5)

    assert %CurWin{val: 5, done: 3, broke: 5, dur: 7} == right
  end
end

defmodule TrendTest do
  use ExUnit.Case
  @idle nil

  test "Trend.make initial state" do
    assert [@idle, @idle, @idle] == Trend.make(3) |> Trend.to_list()
  end

  test "Trend.add sanitises the input" do
    elems = Trend.make(3)
    |> Trend.add(%CurWin{done: 13})
    |> Trend.to_list
    assert elems == [{8, 0}, @idle, @idle]
  end

  test "Trend.add rolls around, keeping the last $size" do
    got = Trend.make(3)
    |> Trend.add(%CurWin{done: 1, broke: 3})
    |> Trend.add(%CurWin{done: 2, broke: 4})
    |> Trend.add(%CurWin{done: 3, broke: 1})
    |> Trend.add(%CurWin{done: 4, broke: 0})
    |> Trend.add(%CurWin{done: 5, broke: 3})
    |> Trend.to_list

    assert got == [{5, 3}, {4, 0}, {3, 1}]
  end

  test "Trend stats give sums of each" do
    got = Trend.make(3)
    |> Trend.add(%CurWin{done: 1, broke: 3})
    |> Trend.add(%CurWin{done: 2, broke: 4})
    |> Trend.add(%CurWin{done: 3, broke: 1})
    |> Trend.add(%CurWin{done: 4, broke: 0})
    |> Trend.add(%CurWin{done: 5, broke: 3})
    |> Trend.stats

    assert got == {12, 4}
  end

  test "stores work and the breaks" do
    win =
      CurWin.make(8)
      |> CurWin.tick(:work, 4)
      |> CurWin.work(3)
      |> CurWin.tick(:break, 2)

    right =
      Trend.make(5)
      |> Trend.add(win)
      |> Trend.to_list()

    assert [{3, 2}, @idle, @idle, @idle, @idle] == right
  end
end

defmodule CircBufTest do
  use ExUnit.Case

  test "can list" do
    elems = Enum.reduce(1..8, CircBuf.make(5, 0), fn x, cb -> CircBuf.add(cb, x) end)
    |> CircBuf.to_list

    assert elems == [8, 7, 6, 5, 4]
  end
end
