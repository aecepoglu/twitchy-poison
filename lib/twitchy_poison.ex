defmodule TwitchyPoison do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: :hub)
  end

  @impl true
  def init(nil) do
    {:ok, Hourglass.make()}
  end

  @impl true
  def handle_cast(:tick, model) do
    Hourglass.tick(model)
    |> render
    |> noreply
  end
  def handle_cast(:progress, model) do
    Hourglass.progress(model, 1)
    |> render
    |> noreply
  end

  def tick() do
    GenServer.cast(:hub, :tick)
  end

  def progress() do
    GenServer.cast(:hub, :progress)
  end

  defp render(model) do
    IO.write("\r" <> Hourglass.to_string(model))
    model
  end

  defp noreply(x), do: {:noreply, x}
end
