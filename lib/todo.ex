defmodule Todo.Hook do
  def run!(list) do
    list
    |> Keyword.filter(fn {key, _} -> key == :todobqn end)
    |> Keyword.values
    |> External.TodoBqn.complete(:ids)
  end
end

defmodule Todo.Parser do
  def parse(label, has_todobqn: true) do
    with [h | t] <- String.split(label, "\t"),
         {_, _}  <- Integer.parse(h)
    do
      %{hooks: [todobqn: h], label: Enum.join(t, "\t"), done: false}
    else
      _ -> %{label: label}
    end
  end
end

defmodule Todo do
  defstruct [
    :label,
    done: false,
    hooks: []
  ]

  def empty(), do: []

  def envelop(todos, title) when is_binary(title) do
    x = struct(Todo, Todo.Parser.parse(title, has_todobqn: true))
        |> Map.put(:done, true)

    case todos do
      [h | t] when is_list(h) -> [[x | Enum.map(h, &mark_done!/1)] | t]
      [h | t]                 -> [[x, mark_done!(h)] | t]
      []                      -> [[x]]
    end
  end

  def rot([h | t], :outside), do: add(t, h, :last)
  def rot([[hh | ht] | t], _) , do: [add(ht, hh, :last) | t]
  def rot(x, _), do: x

  def swap([h1, h2 | t]), do: [h2, h1 | t]

  def disband([h | t]) when is_list(h), do: h ++ t
  def disband(x), do: x

  def join([h1, h2 | t]), do: [join_(h1, h2) | t]
  def join(x), do: x

  def join_eager(list) do
    {left, right} = Enum.split_while(list, & not(is_list(&1)))
    [left | right]
  end

  def add( [],      x, _    ), do: [x]
  def add( [h | t], x, :next) when h.done, do: [x, h | t]
  def add( [h | t], x, :next), do: [h, x | t]
  def add( [h | t], x, :push), do: [x, h | t]
  def add( [%Todo{done: true}|_]=t, x, :last), do: [x | t]
  def add([[%Todo{done: true}|_] | _]=t, x, :last), do: [x | t]
  def add( [h | t], x, :last), do: [h | add(t, x, :last)]

  def pop([[h1, h2] | t]), do: [h1, h2 | t]
  def pop([[hh | ht] | t]), do: [hh | [ht | t]]
  def pop(x), do: x

  def del([[_] | t]), do: t
  def del([[_ | ht] | t]), do: [ht | t]
  def del([_ | t]), do: t
  def del([]), do: []

  def mark_done!([%Todo{}=h | t]) do
    t ++ [mark_done!(h)]
  end
  def mark_done!([h | t]) when is_list(h) , do: [mark_done!(h) | t]
  def mark_done!(%Todo{done: false, hooks: hooks}=x) do
    Todo.Hook.run!(hooks)
    %{x | done: true}
  end
  def mark_done!(x), do: x

  defp join_(a, b), do: enlist(a) ++ enlist(b)

  defp enlist(x) when is_list(x), do: x
  defp enlist(x), do: [x]

  def strings(list, width, opts \\ [color: false]) do
    list
    |> Enum.flat_map(&lines_of_one(&1, width, opts))
  end

  defp lines_of_one(%Todo{}=x, width, opts) do
    str(x, width, opts)
    |> add_grp_decor(false)
  end
  defp lines_of_one(list, width, opts) do
    Enum.flat_map(list, &str(&1, width, opts))
    |> add_grp_decor(true)
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
  defp add_grp_decor(lines, false) do
    lines
    |> Enum.map(&"  " <> &1)
  end

  defp str(%Todo{done: d, label: l}=t, width, color: has_colors?) do
    # [hd | tl] = fold(l, width - 4, []) # 2 (decor) + 2 (bullet) = 4
    [hd | tl] = String.Wrap.wrap(l, width - 4)
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

  def render(todos, {width, height}) do
    lines = todos
    |> strings(width, color: true)
    |> Enum.take(height) # TODO fix
    |> Enum.map(fn x -> IO.ANSI.clear_line <> x end)

    {length(lines), Enum.join(lines, "\n\r")}
  end

  def upsert_head([_ | t], h), do: [h | t]
  def upsert_head([],      h), do: [h]

  def dump_cur([h | _]) when is_list(h), do: serialise(h)
  def dump_cur([h | _]), do: serialise([h])
  def dump_cur([]), do: []

  defp serialise([h | t]) do
    bullet = if h.done do "x" else " " end
    h_ = "#{bullet} #{h.label}"
    t_ = serialise(t)
    [h_ | t_]
  end
  defp serialise([]), do: []

  defp bullet_to_str(%Todo{done: true}),  do: "✔"
  defp bullet_to_str(%Todo{done: false}), do: "⋅"

  def deserialise(lines) when is_list(lines), do: Enum.map(lines, &deserialise/1)
  def deserialise(txt) do
    {done, rest} =  case txt do
      "x " <> k -> {true, k}
      "  " <> k -> {false, k}
      k         -> {false, k}
    end

    %Todo{
      done: done,
      label: rest,
    }
  end

  def persist!([%Todo{}=h | t]) do
    External.TodoBqn.add(h.label)
    t
  end
  def persist!([h | t]) when is_list(h), do: [persist!(h) | t]
end
