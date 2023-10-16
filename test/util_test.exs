defmodule String.WrapTest do
  use ExUnit.Case

  test "wrapping with a big initial indentation" do
    assert String.Wrap.wrap("45 67890", 5, first_indentation: 8) == ["", "45", "67890"]
  end

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

  test "takes indent: _ to fold" do
    lines = "one two eight nine t123456789ABCDEFn Z."
     |> String.Wrap.wrap(12, indent: ">_")

    assert lines == """
one two
>_eight nine
>_t123456789
>_ABCDEFn Z.
""" |> String.trim_trailing
    |> String.split("\n")
  end

  test "empty lines also fold" do
    assert String.Wrap.wrap("", 10) == [""]
  end

  test "lines perfectly fit" do
    assert String.Wrap.wrap("1234567890", 10) == ["1234567890"]
  end
end
