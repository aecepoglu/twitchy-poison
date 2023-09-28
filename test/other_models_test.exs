defmodule CircBufTest do
  use ExUnit.Case

  test "can list" do
    elems = Enum.reduce(1..8, CircBuf.make(5, 0), fn x, cb -> CircBuf.add(cb, x) end)
    |> CircBuf.to_list

    assert elems == [8, 7, 6, 5, 4]
  end
end
