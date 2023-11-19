defmodule CircBufTest do
  use ExUnit.Case

  import CircBuf

  test "can list" do
    elems = Enum.reduce(1..8, make(5, 0), fn x, cb -> add(cb, x) end)
    |> CircBuf.to_list

    assert elems == [8, 7, 6, 5, 4]
  end

  test "scan" do
    list = make(4, 0)
    |> add(4)
    |> add(3)
    |> add(2)
    |> add(1)
    |> scan_bi(10, fn x, acc -> {x + acc, x + acc} end)
    |> to_list

    assert list == (1..4 |> Enum.scan(10, & &1 + &2))
  end

  test "scan bi" do
    list = make(4, 0)
    |> add(4)
    |> add(3)
    |> add(2)
    |> add(1)
    |> scan_bi(10, fn x, acc -> {acc, x} end)
    |> to_list

    assert list == [10, 1, 2, 3]
  end

  test "reduce_while" do
    cb = make(10, nil)
    |> add(:one)
    |> add(:two)
    |> add(:tree) # 1
    |> add(:four) # 2
    |> add(:five)
    |> add(:six)      #2
    |> add(:sevn)     #1

    f = fn x, acc ->
      if length(acc) < 2 do
        {:continue, [x | acc]}
      else
        "just stop"
      end
    end
    fin = reduce_while(cb, [], f, offset: 4, step: 1)
    assert fin == [:tree, :four]
  end
end
