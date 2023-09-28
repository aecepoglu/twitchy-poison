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

  def tick(curwin, mode, d_val \\ 1)
  def tick(%__MODULE__{broke: v} = x, :break, d_val), do:
    %__MODULE__{x | broke: v + d_val,
                    val: v + d_val}
  def tick(%__MODULE__{val: v} = x, _, d_val), do:
    %__MODULE__{x | val: v + d_val}

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
