defmodule CircBufTest do
  use ExUnit.Case

  test "can list" do
    elems = Enum.reduce(1..8, CircBuf.make(5, 0), fn x, cb -> CircBuf.add(cb, x) end)
    |> CircBuf.to_list

    assert elems == [8, 7, 6, 5, 4]
  end

  test "scan" do
    list = CircBuf.make(4, 0)
    |> CircBuf.add(4)
    |> CircBuf.add(3)
    |> CircBuf.add(2)
    |> CircBuf.add(1)
    |> CircBuf.scan_bi(10, fn x, acc -> {x + acc, x + acc} end)
    |> CircBuf.to_list

    assert list == (1..4 |> Enum.scan(10, & &1 + &2))
  end

  test "scan bi" do
    list = CircBuf.make(4, 0)
    |> CircBuf.add(4)
    |> CircBuf.add(3)
    |> CircBuf.add(2)
    |> CircBuf.add(1)
    |> CircBuf.scan_bi(10, fn x, acc -> {acc, x} end)
    |> CircBuf.to_list

    assert list == [10, 1, 2, 3]
  end
end
