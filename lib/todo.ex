defmodule Todo do
  defstruct [
    :label,
    done?: false
  ]

  def empty(), do: []

  def rot([[hh | ht] | t]) , do: [(ht ++ [hh]) | t]
  def rot([h | t]), do: t ++ [h]

  def disband([h | t]) when is_list(h), do: h ++ t

  def join([h1, h2 | t]), do: [join_(h1, h2) | t]

  def add(list, x), do: [x | list]

  def del([[_, hh | ht] | t]), do: [[hh | ht] | t]
  def del([_ | t]), do: t

  def mark_done([h | t]) when is_list(h) , do: [mark_done(h) | t]
  def mark_done([h | t]), do: [%{h | done?: !h.done?} | t]

  defp join_(a, b), do: enlist(a) ++ enlist(b)

  defp enlist(x) when is_list(x), do: x
  defp enlist(x), do: [x]

  def strings([]), do: []
  def strings([h | t]) do
    grp? = is_list(h)
    h_ = if grp? do
      strings_(h, :head)
    else
      str(h)
    end
    |> add_grp_decor(grp?)

    h_ ++ strings(t)
  end

  defp add_grp_decor(lines, false) do
    Enum.map(lines, & "  " <> &1)
  end
  defp add_grp_decor(lines, true) do
    n = length(lines)
    Enum.with_index(lines, fn x, i ->
      b = case {i, n} do
        {0, 1}                 -> "< "
        {0, _}                 -> "╭ "
        {i, j} when i == j - 1 -> "╰ "
        {_, _}                 -> "│ "
      end
      b <> x
    end)
  end

  defp strings_([h], :head), do: str(h)
  defp strings_([h | t], :head), do: str(h) ++ strings_(t, :tail)
  defp strings_([h    ], :tail), do: str(h)
  defp strings_([h | t], :tail), do: str(h) ++ strings_(t, :tail)
  defp strings_([], _), do: []

  defp str(%Todo{done?: d, label: l}) do
    width = 40 # FIXME
    [hd | tl] = fold(l, width - 6, [])
    pre = "[#{bullet_to_str(d)}] "
    hd_ = pre <> hd
    tl_ = tl |> Enum.map(& "    " <> &1)
    [hd_ | tl_]
  end

  defp fold(txt, width, acc) do
    if String.length(txt) > width do
      {left, right} = String.split_at(txt, width)
      fold(right, width, [left | acc])
    else
      [txt | acc] |> Enum.reverse
    end
  end

  def render(todos) do
    todos
    |> strings
    |> Enum.map(fn x -> IO.ANSI.clear_line <> x end)
    |> Enum.join("\n\r")
    |> IO.puts
  end

  def upsert_head([_ | t], h), do: [h | t]
  def upsert_head([],      h), do: [h]

  def dump_cur([h | _]) when is_list(h), do: serialise(h)
  def dump_cur([h | _]), do: serialise([h])
  def dump_cur([]), do: []

  defp serialise([h | t]) do
    h_ = "#{bullet_to_str(h.done?)} #{h.label}"
    t_ = serialise(t)
    [h_ | t_]
  end
  defp serialise([]), do: []

  defp bullet_to_str(true),  do: "x"
  defp bullet_to_str(false), do: " "

  def deserialise(lines) when is_list(lines), do: Enum.map(lines, &deserialise/1)
  def deserialise("x " <> l), do: %Todo{done?: true , label: l}
  def deserialise("  " <> l), do: %Todo{done?: false, label: l}
end
