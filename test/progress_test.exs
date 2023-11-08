defmodule TrendTest do
  use ExUnit.Case
  alias Progress.Trend, as: Trend

  test "stats gives tally of everything" do
    1..50
    |> Enum.each(fn duration ->
        activity = random_activity(duration)
        trend = activity |> log_activity(Trend.make())
        stats = trend |> Trend.stats
        expected = Map.merge(
          %{work: 0, break: 0, idle: 0},
          Enum.frequencies(activity)
        )
        assert stats == expected
      end)
  end

  test "recent_stats takes stats only after the 1st break" do
    1..50
    |> Enum.each(fn duration ->
        break_duration = Enum.random(max(4 - duration, 1)..30)
        break = 1..break_duration |> Enum.map(fn _ -> :break end)

        activity = random_activity(duration, [:idle, :work])

        stats_after_break =
          random_activity(32)
          ++ random_activity(4, [:idle, :work])
          ++ break
          ++ activity
          |> log_activity(Trend.make())
          |> Trend.recent_stats

        stats_from_scratch =
          activity
          |> log_activity(Trend.make())
          |> Trend.recent_stats
          |> Map.put(:break, break_duration)

        assert stats_after_break == stats_from_scratch
      end)
  end

  test "idle? is truthy if we've idled for long enough" do
    idle = random_activity(32)
      ++ random_activity(4, [:work, :break])
      ++ random_activity(30, [:idle])
      |> log_activity(Trend.make())
      |> Trend.idle

    assert idle == 30
  end

  test "idle? is not truthy if I've done any work" do
    idle = random_activity(32)
      ++ random_activity(4, [:work, :break])
      ++ random_activity(30, [:idle])
      ++ random_activity(1, [:work])
      |> log_activity(Trend.make())
      |> Trend.idle

    assert idle == 0
  end

  defp random_activity(length, opts \\ [:idle, :work, :break]) do
    Enum.map(1..length, fn _ -> Enum.random(opts) end)
  end

  defp log_activity(activity, trend) when is_list(activity) do
    Enum.reduce(activity, trend, &log_activity/2)
  end
  defp log_activity(:idle,  trend), do: Trend.add(trend, {:work, :none})
  defp log_activity(:work,  trend), do: Trend.add(trend, {:work, :small})
  defp log_activity(:break, trend), do: Trend.add(trend, :break)
end
