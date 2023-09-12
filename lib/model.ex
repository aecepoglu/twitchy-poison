defmodule Todo do
  defstruct [
    :label,
    children: [],
    done?: false
  ]

  def mark_done(%Todo{} = x) do
    %{x | done?: true}
  end

  def reword(task, new_label) do
    %{task | label: new_label}
  end

  def rotr(task) do
    # TODO
    task
  end

  def rotl(task) do
    # TODO
    task
  end

  def popnflat(task) do
    # TODO
    task
  end

  def push(parent, _child) do
    # TODO
    parent
  end

  def add_to_top(parent, _child) do
    # TODO
    parent
  end

  def add_to_bottom(parent, _child) do
    # TODO
    parent
  end

  def stash(parent) do
    # TODO
    parent
  end

  def unstash(parent) do
    # TODO
    parent
  end
end

defmodule CurWin do
  defstruct dur: 8,
            val: 0,
            done: 0,
            broke: 0,
            mode: :work

  def tick(%__MODULE__{} = x) do
    %{x | val: x.val + 1}
  end

  def progress(%__MODULE__{} = x, d_val) do
    k = case x.mode do
      :work -> :done
      _ -> :broke
    end
    %{x | k => x[k] + d_val}
  end
end

defmodule CircBuf do
  defstruct [
    :size,
    idx: 0,
    buf: %{}
  ]

  def make(n, fill) do
    %__MODULE__{size: n, buf: Map.new(0..(n - 1), &{&1, fill})}
  end

  def add(%__MODULE__{} = cb, val) do
    %{cb | idx: rem(cb.idx + 1, cb.size), buf: %{cb.buf | cb.idx => val}}
  end

  def take(%__MODULE__{} = cb, n) do
    0..n
    |> Enum.map(fn x -> cb.buf[rem(cb.idx + x, cb.size)] end)
  end
end

defmodule Trend do
  def make(len) do
    CircBuf.make(len, 0)
  end

  def add(trend, %CurWin{} = win) do
    CircBuf.add(trend, win.done)
  end

  def idle_too_long?(trend) do
    trend
    |> CircBuf.take(2)
    |> Enum.all?(fn x -> x == 1 end)
  end

  def worked_too_long?(trend) do
    trend
    |> CircBuf.take(5)
    |> Enum.all?(fn x -> x > 0 end)
  end

  def to_list(x) do
    Map.values(x.buf)
  end
end

defmodule Hourglass do
  def tick({_past, _win, _upcoming} = model, dt) do
    model
    |> tick_up(dt)
    |> decr_upcoming
    |> create_idle_notifications()
  end

  def remove_plan(model) do
    # TODO
    model
  end

  defp tick_up({past, %CurWin{} = x, upcoming}, dt) do
    val_ = rem(x.val + dt, x.dur)
    {past, %{x | val: val_}, upcoming}
  end

  defp decr_upcoming({past, win, upcoming}) do
    upcoming_ = upcoming
    {past, win, upcoming_}
  end

  defp create_idle_notifications({past, win, upcoming}) do
    upcoming_ =
      if Trend.idle_too_long?(past) do
        # TODO
        upcoming
      else
        upcoming
      end

    {past, win, upcoming_}
  end
end

defmodule Test_WIP do
  def foo() do
    right =
      100..107
      |> Enum.map(fn x -> %CurWin{done: x} end)
      |> Enum.reduce(Trend.make(5), fn x, a -> Trend.add(a, x) end)

    %CircBuf{size: 5, idx: 3, buf: %{0 => 105, 1 => 106, 2 => 107, 3 => 103, 4 => 104}} = right
  end
end
