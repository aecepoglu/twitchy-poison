defmodule Progress.CurWin do
  defstruct [dur: 8,
             val: 0,
             done: 0,
             broke: 0,
            ]

  def make(duration) do
    %__MODULE__{dur: duration}
  end

  def fin?(%__MODULE__{val: v, dur: d}), do: v >= d
  def reset(%__MODULE__{}=x), do:
    %__MODULE__{x | val: 0, done: 0, broke: 0}
  def sub(%__MODULE__{}=x, dv), do:
    %__MODULE__{x | val: 0, done: max(0, x.done - dv), broke: 0}

  def tick(%__MODULE__{} = x, mode, d_val \\ 1) do
    %__MODULE__{x | val: x.val + d_val}
    |> tick_(mode, d_val)
  end
  def tick_(%__MODULE__{} = x, :meeting, d_val), do: %__MODULE__{x | done: x.done + d_val}
  def tick_(%__MODULE__{} = x, :break  , d_val), do: %__MODULE__{x | broke: x.broke + d_val}
  def tick_(%__MODULE__{} = x, _       , _    ), do: x

  def work(%__MODULE__{} = x, d_val), do: %{x | done: x.done + d_val}

  def string(%__MODULE__{}=x) do
    case {x.val, x.dur} do
      {0, 4} -> "○"
      {1, 4} -> "◔"
      {2, 4} -> "◑"
      {3, 4} -> "◕"
      {4, 4} -> "●"
           _ -> "?"
    end
  end

  def idle?(x), do: x.done == 0
end
