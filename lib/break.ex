defmodule Break do
  defstruct [t: 60, chore: nil]

  def make(suggested_duration) do
    %__MODULE__{t: max(suggested_duration, 60)}
  end

  def make_longer(%__MODULE__{t: t}=s), do: %{s | t: t + 60}
  def make_shorter(%__MODULE__{t: t}=s), do: %{s | t: max(60, t - 60)}

  def tick(%__MODULE__{t: t}=s) when t <= 0, do: s
  def tick(%__MODULE__{t: t}=s), do: %{s | t: t - 1}

  def set_chore(%__MODULE__{}=break, chores) when is_list(chores) do
    t = break.t / 60
    %{break | chore: Enum.find(chores, & &1.duration <= t)}
  end

  def render(%__MODULE__{}=break, :breakprep, _size) do
    ["Plan your next break:",
     "",
     "Chore: " <> Chore.string(break.chore),
     "countdown from " <> duration_str(break.t)
    ]
    |> Enum.join("\n\r")
    |> IO.write
  end

  def render(%__MODULE__{}=break, :break, _size) do
    ["You are on a break:",
     "",
     "Chore: " <> Chore.string(break.chore),
     "",
     if break.t > 0 do
       "counting down from " <> duration_str(break.t)
     else
       IO.ANSI.reverse() <> "time over" <> IO.ANSI.reverse_off()
     end,
    ]
    |> Enum.join("\n\r")
    |> IO.write
  end

  defp duration_str(t) do
       "#{floor(t / 60)}' #{rem(t, 60)}\""
  end
end
