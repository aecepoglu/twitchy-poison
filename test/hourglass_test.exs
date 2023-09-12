defmodule HourglassTest do
  use ExUnit.Case

  test "Trend .make, .add .to_list" do
    right =
      100..107
      |> Enum.map(fn x -> %CurWin{done: x} end)
      |> Enum.reduce(Trend.make(5), fn x, a -> Trend.add(a, x) end)
      |> Trend.to_list()

    assert [105, 106, 107, 103, 104] == right
  end
end
