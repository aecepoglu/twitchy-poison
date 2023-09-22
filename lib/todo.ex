defmodule Todo.Hook do
  def run!([]), do: nil
  def run!([{:todobqn, _key} | _]), do: nil
end

defmodule Todo.Parser do
  def parse(txt) do
    found = String.split(txt)
    |> Enum.map(&categorise/1)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    label = Map.get(found, :label, []) |> Enum.join(" ")
    defaults = %{
      label: "",
      hook: nil,
    }

    defaults
    |> Map.merge(found)
    |> Map.merge(%{label: label})
  end
  defp categorise("todobqn:" <> key), do: {:hook, {:todobqn, key}}
  defp categorise(x), do: {:label, x}
end

defmodule Todo do
  defstruct [
    :label,
    done?: false,
    hook: []
  ]

  def empty(), do: []

  def rot([h | t], :outside), do: t ++ [h]
  def rot([[hh | ht] | t], _) , do: [(ht ++ [hh]) | t]

  def swap([h1, h2 | t]), do: [h2, h1 | t]

  def disband([h | t]) when is_list(h), do: h ++ t
  def disband(x), do: x

  def join([h1, h2 | t]), do: [join_(h1, h2) | t]
  def join(x), do: x

  def join_eager([]), do: []
  def join_eager([h]), do: [h]
  def join_eager([h1, h2 | t]) when is_list(h2), do: [h1, h2 | t]
  def join_eager([h1, h2 | t]) when is_list(h1), do: join_eager([(h1 ++ [h2]) | t])
  def join_eager([h1, h2 | t])                 , do: join_eager([[h1, h2] | t])

  def add([h | t]                    , x, :push_in) when is_list(h), do: [[x | h] | t]
  def add([h | t]                    , x, :push_in),                 do: [[x, h] | t]
  def add(ht                         , x, :push_out), do: [x | ht]
  def add([h | t]                    , x, :last) when is_list(h), do: [add(h, x, :last) | t]
  def add([%Todo{done?: true}|_]=list, x, :last), do: [x | list]
  def add([h | t]                    , x, :last), do: [h | add(t, x, :last)]
  def add([]                         , x, :last), do: [x]

  def pop([[hh | ht] | t]), do: [hh | [ht | t]]
  def pop(x), do: x

  def del([[_, hh | ht] | t]), do: [[hh | ht] | t]
  def del([_ | t]), do: t
  def del([]), do: []

  def mark_done!([%Todo{done?: false}=h | t]), do: t ++ [%{h | done?: true}]
  def mark_done!([h | t]) when is_list(h) , do: [mark_done!(h) | t]
  def mark_done!([]), do: []

  defp join_(a, b), do: enlist(a) ++ enlist(b)

  defp enlist(x) when is_list(x), do: x
  defp enlist(x), do: [x]

  def strings(list, width, opts \\ [color: false]) do
    list
    |> Enum.map(&strings_(&1, width, opts))
    |> Enum.flat_map(&add_grp_decor/1)
  end

  defp strings_(list, width, opts) do
    list
    |> enlist
    |> Enum.flat_map(& str(&1, width, opts))
  end

  defp add_grp_decor([line]), do: ["  " <> line]
  defp add_grp_decor(lines) do
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

  defp str(%Todo{done?: d, label: l}=t, width, color: has_colors?) do
    [hd | tl] = fold(l, width - 4, []) # 2 (decor) + 2 (bullet) = 4
    hd_ = bullet_to_str(t) <> " " <> hd
    tl_ = tl |> Enum.map(& "  " <> &1)
    lines = [hd_ | tl_]
    if has_colors? do
      color(lines, d)
    else
      lines
    end
  end

  defp color(x, false), do: x
  defp color(lines, true), do: Enum.map(lines, fn x -> IO.ANSI.faint <> x <> IO.ANSI.normal end)

  defp fold(txt, width, acc) do
    if String.length(txt) > width do
      {left, right} = String.split_at(txt, width)
      fold(right, width, [left | acc])
    else
      [txt | acc] |> Enum.reverse
    end
  end

  def render(todos, {width, _height}) do
    todos
    |> strings(width, color: true)
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
    bullet = if h.done? do "x" else " " end
    h_ = "#{bullet} #{h.label}"
    t_ = serialise(t)
    [h_ | t_]
  end
  defp serialise([]), do: []

  defp bullet_to_str(%Todo{done?: true}), do: "●"
  defp bullet_to_str(%Todo{done?: false, hook: []}), do: "○"
  defp bullet_to_str(%Todo{done?: false, hook: _}), do: "◬"

  def deserialise(lines) when is_list(lines), do: Enum.map(lines, &deserialise/1)
  def deserialise(txt) do
    {done, rest} =  case txt do
      "x " <> k -> {true, k}
      "  " <> k -> {false, k}
    end
    x = %Todo{} = struct!(Todo, Todo.Parser.parse(rest))
    %{x | done?: done}
  end
end
