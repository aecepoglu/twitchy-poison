defmodule String.Wrap do
  def wrap_lines(texts, width) do
    Enum.flat_map(texts, &wrap(&1, width, indent: ""))
  end

  def wrap(str, width, opts \\ []) when is_binary(str) and is_integer(width) do
    indent = Keyword.get(opts, :indent, "")
    str
    |> String.split(" ")
    |> Enum.map(& {&1, String.length(&1)})
    |> wrap(0, [], [], {width, String.length(indent)})
    |> Enum.reverse
    |> Enum.with_index(fn words, i ->
        k = words
        |> Enum.reverse
        |> Enum.join(" ")
        (if i > 0 do indent else "" end) <> k
      end)
  end
  def wrap(_, _, _, lines, {limit, indentation}) when indentation >= limit, do: lines
  def wrap([], _, words, lines, _), do: [words | lines]
  def wrap([{word, wordlen} | tl]=rmd, linelen, words, lines, {limit, indentation}=opts)  do
    # IO.inspect({rmd, linelen, words, lines, opts})
    cond do
      wordlen + linelen <= limit ->
        wrap(tl, wordlen + linelen + 1, [word | words], lines, opts)
      wordlen + indentation > limit ->
        {left, right} = String.split_at(word, limit - indentation)
        lines_ = case words do
          [] -> [[left] | lines]
          _  -> [[left], words | lines]
        end
        wrap([{right, wordlen - limit} | tl], indentation, [], lines_, opts)
      true ->
        wrap(rmd, indentation, [], [words | lines], opts)
    end
  end
end
