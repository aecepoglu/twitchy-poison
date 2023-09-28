defmodule String.WrapTest do
  use ExUnit.Case

  test "text folds at given width" do
    lines = """
one two three four five six seven
eight nine ten eleven twelve
thirteen fourteen
fifteeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeen sixteen

seventeen
""" |> String.split("\n")
    |> String.Wrap.wrap_lines(20)


    assert lines == """
one two three four
five six seven
eight nine ten
eleven twelve
thirteen fourteen
fifteeeeeeeeeeeeeeee
eeeeeeeeeeeeeeeeeeee
eeen sixteen

seventeen
""" |> String.split("\n")
  end

  test "empty lines also fold" do
    assert String.Wrap.wrap("", 10) == [""]
  end

  test "lines perfectly fit" do
    assert String.Wrap.wrap("1234567890", 10) == ["1234567890"]
  end
end
