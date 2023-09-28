defmodule String.Wrap do
  def wrap_lines(texts, width) do
    Enum.flat_map(texts, &wrap(&1, width))
  end

  def wrap(str, width) when is_binary(str) and is_integer(width) do
    str
    |> String.split(" ")
    |> Enum.map(& {&1, String.length(&1)})
    |> wrap(0, [], [], width)
    |> Enum.map(fn words ->
        words
        |> Enum.reverse
        |> Enum.join(" ")
      end)
    |> Enum.reverse
  end
  def wrap([], _, words, lines, _), do: [words | lines]
  def wrap([{word, wordlen} | tl]=rmd, linelen, words, lines, limit)  do
    cond do
      wordlen + linelen <= limit ->
        wrap(tl, wordlen + linelen + 1, [word | words], lines, limit)
      wordlen >= limit ->
        {left, right} = String.split_at(word, limit)
        lines_ = case words do
          [] -> [[left] | lines]
          _  -> [[left], words | lines]
        end
        wrap([{right, wordlen - limit} | tl], 0, [], lines_, limit)
      true ->
        wrap(rmd, 0, [], [words | lines], limit)
    end
  end
end
