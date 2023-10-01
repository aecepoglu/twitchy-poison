# just a generic backup thingy
defmodule Backup do
  use Agent

  def start_link(state, opts) do
    {:ok, _} = Agent.start_link(fn -> state end, opts)
  end
  def get(pid), do: Agent.get(pid, & &1)
  def set(v, pid) do
    Agent.update(pid, fn _ -> v end)
    v
  end

  def child_spec([for_module, state | args]) do
    %{id: for_module, start: {__MODULE__, :start_link, [state, args]}}
  end
end

