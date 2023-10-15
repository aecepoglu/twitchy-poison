defmodule String.WrapTest do
  use ExUnit.Case
  import IO.ANSI
  @colors [red(), blue(), "\e[38;2;123;456;789m", default_color()]

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

  @tag :skip
  test "text with coloured words is split at correct spots" do
    lines = [
      red() <> "hello" <> default_color() <> ", world"
    ]
    |> String.Wrap.wrap_lines(20)


    assert lines == [red() <> "hello" <> default_color() <> ", world"]
  end

  @tag :skip
  test "text with one long coloured words is split at correct spots" do
    lines = [
      red() <> "1234567890123456" <> default_color() <> " fin"
    ]
    |> String.Wrap.wrap_lines(10)

    assert lines == [
      red() <> "1234567890",
               "123456"     <> default_color() <> " fin",
    ]
  end

  test "colouring text doesn't change how it is split" do
    text = "one two three four five six"
    len = String.length(text)
    colors = @colors ++ Enum.map(1..7, fn _ -> "" end)
    Enum.each(1..10, fn _ ->
      text
      |> String.graphemes()
      |> Enum.map(& &1<> Enum.random(colors))
      |> Enum.join

      {left, right} = String.split_at(text, Enum.random(0..len))
      assert {
        String.Wrap.esc_strlen(left),
        String.Wrap.esc_strlen(right)
      } == {
        String.length(left),
        String.length(right)
      }
    end)
  end

  @tag :skip
  test "split_at works the same for normal strings" do
    text = "one two three four five six"
    len = String.length(text)
    Enum.each(0..(len + 3), fn i ->
      assert String.Wrap.esc_split_at(text, i)
        == String.split_at(text, i)
      end)
  end

  test "colouring text doesn't change its length" do
    text = "some text"
    colors = @colors ++ Enum.map(1..7, fn _ -> "" end)
    Enum.each(1..10, fn _ ->
      text
      |> String.graphemes()
      |> Enum.map(& &1<> Enum.random(colors))
      |> Enum.join

      assert String.Wrap.esc_strlen(text) == String.length(text)
    end)
  end

  @tag :skip
  test "coloured text folds like uncoloured text" do
    wordlens = [0,1,2,2,3,3,3,4,4,7,8,10,17,23]
    colors = @colors ++ Enum.map(1..61, fn _ -> "" end)

    Enum.each(1..32, fn _ ->
      indent = Enum.random(["", ">__"])
      opts = [indent: indent]
      text = 1..10
      |> Enum.map(fn _ -> Enum.random(wordlens) |> make_word end)
      |> Enum.join(" ")

      text2 = text
      |> String.graphemes()
      |> Enum.map(& Enum.random(colors) <> &1)
      |> Enum.join

      lines1 = text
      |> String.Wrap.wrap(10, opts)

      lines2 = text2
      |> String.Wrap.wrap(10, opts)
      |> Enum.map(fn line -> String.replace(line, ~r"\e\[3.m", "")  end)

      if lines1 != lines2 do
        IO.puts(indent <> text)
        IO.inspect(text2)
      end
      assert lines1 == lines2
    end)
  end

  @alphabet 'abcdefghjklmno'
  defp make_word(len) do
    1..len
    |> Enum.map(fn _ -> Enum.random(@alphabet) end)
    |> to_string
  end
end
