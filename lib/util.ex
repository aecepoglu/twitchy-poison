defmodule String.Wrap do
  def wrap_lines(texts, width) do
    Enum.flat_map(texts, &wrap(&1, width, indent: ""))
  end

  def wrap(str, width, opts \\ []) when is_binary(str) and is_integer(width) do
    indent = Keyword.get(opts, :indent, "")
    
    str
    |> String.split(" ")
    |> Enum.map(fn x -> {x, String.length(x)} end)
    |> wrap(0, [], [], {width, String.length(indent)})
    |> Enum.map(fn x ->
        x
        |> Enum.reverse
        |> Enum.join(" ")
      end)
    |> Enum.reverse
    |> Enum.with_index(fn x, i ->
        (if i > 0 do indent else "" end) <> x
      end)
  end

  def wrap(_, _, _, lines, {limit, indentation}) when indentation >= limit, do: lines
  def wrap([], _, words, lines, _), do: [words | lines]
  def wrap([{word, wordlen} | tl]=rmd, linelen, words, lines, {limit, indentation}=opts) do
    #IO.inspect({"WRAP()", {word, wordlen}, linelen, words, {limit, indentation}})
    cond do
      wordlen + linelen <= limit ->
        wrap(tl, wordlen + linelen + 1, [word | words], lines, opts)
      linelen >= limit ->
        wrap(rmd, indentation, [], [words | lines], opts)
      wordlen + indentation > limit ->
        i = limit - linelen # ensured to be > 0
        {left, right} = String.split_at(word, i)
        lines_ = [[left | words] | lines]
        wrap([{right, wordlen - i} | tl], indentation, [], lines_, opts)
      true ->
        wrap(rmd, indentation, [], [words | lines], opts)
    end
  end

  def esc_strlen(x), do: x |> String.to_charlist |> strlen(0)
  defp strlen([                      ], a), do: a
  #            \e  [  3|4  _  m
  defp strlen([27, 91, 51, _, 109 | t], a), do: strlen(t, a)
  defp strlen([27, 91, 52, _, 109 | t], a), do: strlen(t, a)
  #            \e  [   n  m
  defp strlen([27, 91, n, 109 | t], a) when n in 48..57, do: strlen(t, a)
  defp strlen([_ | t                 ], a), do: strlen(t, a + 1)

  def esc_split_at(str, n) do
    {left, right} = str
    |> String.to_charlist()
    |> split_at(n, [])
    {to_string(left), to_string(right)}
  end
  defp split_at(t,  0, acc), do: {Enum.reverse(acc), t}
  defp split_at([], _, acc), do: split_at([], 0, acc)
  defp split_at([27, 91, 51, fg, 109 | t], n, acc), do:
    split_at(t, n, ([27, 91, 51, fg, 109] |> Enum.reverse) ++ acc)
  defp split_at([h | t], n, acc), do: split_at(t, n - 1, [h | acc])
end
