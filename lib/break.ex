defmodule Break do
  defstruct [t: 60, chore: nil]

  def make(suggested_duration) do
    %__MODULE__{t: max(suggested_duration, 60)}
  end

  def tick(%__MODULE__{t: t}=s) when t <= 0, do: s
  def tick(%__MODULE__{t: t}=s), do: %{s | t: t - 1}

  # TODO all these updates require awareness of %Model{} far too much

  def update(_, {:key, :return}, m) when m.mode == :break, do: %{m | mode: :work}
  def update(_, {:key, :escape}, m), do: %{m | mode: :work, tmp: nil}
  def update(_, _, m), do: m

  def render(%__MODULE__{}=break, _size) do
    ["You are on a break:",
     "",
     "Chore: " <> Chore.string(break.chore),
     "",
     if break.t > 0 do
       "counting down from " <> t_str(break)
     else
       IO.ANSI.reverse() <> "time over" <> IO.ANSI.reverse_off()
     end,
    ]
    |> Enum.join("\n\r")
    |> IO.write
  end

  def t_str(%Break{t: t}) do
       "#{floor(t / 60)}' #{rem(t, 60)}\""
  end
end

defmodule BreakPrep do
  def update(_tmp, {:key, :up}, m) do
    tmp_ = m.tmp
    |> make_longer
    |> set_chore(m.chores)

    %{m | tmp: tmp_}
  end

  def update(_tmp, {:key, :down}, m) do
    tmp_ = m.tmp
    |> make_shorter
    |> set_chore(m.chores)

    %{m | tmp: tmp_}
  end

  def update(_tmp, {:key, :right}, m) do
    tmp_ = m.tmp |> set_chore(m.chores)
    chores = m.chores |> Chore.rotate
    %{m | tmp: tmp_, chores: chores}
  end
  def update(_tmp, {:key, :escape}, m), do: %{m | mode: :work, tmp: nil}
  def update(_tmp, {:key, :return}, m), do: %{m | mode: :break}

  def render(%Break{}=brk, _size) do
    ["Plan your next break:",
     "",
     "Chore: " <> Chore.string(brk.chore),
     "countdown from " <> Break.t_str(brk)
    ]
    |> Enum.join("\n\r")
    |> IO.write
  end

  defp make_longer(%Break{t: t}=s), do: %{s | t: t + 60}
  defp make_shorter(%Break{t: t}=s), do: %{s | t: max(60, t - 60)}
  defp set_chore(%Break{}=break, chores) when is_list(chores) do
    t = break.t / 60
    %{break | chore: Enum.find(chores, & &1.duration <= t)}
  end
end
