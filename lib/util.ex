defmodule String.Wrap do
  def wrap_lines(texts, width) do
    Enum.flat_map(texts, &wrap(&1, width, indent: ""))
  end

  def wrap(str, width, opts \\ []) when is_binary(str) and is_integer(width) do
    indent = Keyword.get(opts, :indent, "")
    first_indentation = Keyword.get(opts, :first_indentation, 0)
    
    str
    |> String.split(" ")
    |> Enum.map(fn x -> {x, String.length(x)} end)
    |> wrap(first_indentation, [], [], {width, String.length(indent)})
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
end
