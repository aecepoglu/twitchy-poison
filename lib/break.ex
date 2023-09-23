defmodule Break do
  defstruct [t: 60, label: "untitled break", chore: nil]

  def make(suggested_duration, label), do: make(suggested_duration, label, Chore.pop())
  def make(suggested_duration, label, chore) do
    %__MODULE__{label: label, chore: chore, t: max(suggested_duration, 60)}
  end

  def make_longer(%__MODULE__{t: t}=s), do: %{s | t: t + 60}
  def make_shorter(%__MODULE__{t: t}=s), do: %{s | t: max(60, t - 60)}

  def tick(%__MODULE__{t: t}=s) when t <= 0, do: s
  def tick(%__MODULE__{t: t}=s), do: %{s | t: t - 1}

  def render(%__MODULE__{}=state, :breakprep, _size) do
    ["Plan your next break:",
     "",
     "Chore: " <> if state.chore != nil do state.chore.label else "-" end,
     "countdown from #{state.t}\""
    ]
    |> Enum.join("\n\r")
    |> IO.puts
  end

  def render(%__MODULE__{}=state, :break, _size) do
    ["You are on a break:",
     "",
     "Chore: " <> if state.chore != nil do state.chore.label else "-" end,
     "(1. complete chore) (2. unset chore)",
     "",
     if state.t > 0 do
       "counting down from #{floor(state.t / 60)}' #{rem(state.t, 60)}\""
     else
       IO.ANSI.reverse() <> "time over" <> IO.ANSI.reverse_off()
     end,
    ]
    |> Enum.join("\n\r")
    |> IO.puts
  end
end
