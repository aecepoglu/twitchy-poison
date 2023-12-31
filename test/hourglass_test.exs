defmodule HourglassTest do
  alias Progress.Hourglass, as: Hourglass
  alias Progress.Trend, as: Trend

  use ExUnit.Case

  test "at t=0/4, nothing gets saved" do
      n = Hourglass.make()
      |> Hourglass.past
      |> Trend.to_list
      |> length

      assert n == 0
  end

  test "at t=1/4, nothing gets saved" do
      n = Hourglass.make()
      |> Hourglass.tick(:work)
      |> Hourglass.past
      |> Trend.to_list
      |> length

      assert n == 0
  end

  test "at t=2/4, nothing gets saved" do
      n = Hourglass.make()
      |> Hourglass.tick(:work)
      |> Hourglass.tick(:work)
      |> Hourglass.past
      |> Trend.to_list
      |> length

      assert n == 0
  end

  test "at t=3/4, nothing gets saved" do
      n = Hourglass.make()
      |> Hourglass.tick(:work)
      |> Hourglass.tick(:work)
      |> Hourglass.tick(:work)
      |> Hourglass.past
      |> Trend.to_list
      |> length

      assert n == 0
  end

  test "at t=4/4, something gets saved" do
      n = Hourglass.make()
      |> Hourglass.tick(:work)
      |> Hourglass.tick(:work)
      |> Hourglass.tick(:work)
      |> Hourglass.tick(:work)
      |> Hourglass.past
      |> Trend.to_list
      |> length

      assert n == 1
  end

  test "at t=5/4, something gets saved" do
      n = Hourglass.make()
      |> Hourglass.tick(:work)
      |> Hourglass.tick(:work)
      |> Hourglass.tick(:work)
      |> Hourglass.tick(:work)
      |> Hourglass.tick(:work)
      |> Hourglass.past
      |> Trend.to_list
      |> length

      assert n == 1
  end

  test "keeping record of time passing by" do
    trend =
      Hourglass.make()
      |> Hourglass.progress(:small)
      |> Hourglass.tick(:work)
      |> Hourglass.progress(:small)
      |> Hourglass.tick(:work)
      |> Hourglass.tick(:break)
      |> Hourglass.tick(:work)

      |> Hourglass.progress(:big)
      |> Hourglass.tick(:work)
      |> Hourglass.progress(:small)
      |> Hourglass.tick(:work)
      |> Hourglass.progress(:small)
      |> Hourglass.tick(:break)
      |> Hourglass.progress(:small)
      |> Hourglass.tick(:work)

      |> Hourglass.progress(:big)
      |> Hourglass.tick(:work)
      |> Hourglass.past
      |> Trend.to_list
    assert trend == [{7, 1, 4}, {7, 1, 4}]
  end

  test "the big additions get carried over to the past" do
    list = Trend.make()
    |> Trend.add({:work, :none})
    |> Trend.add({:work, :none})
    |> Trend.add({:work, :none})
    |> Trend.add({:work, :none}) #
    |> Trend.add({:work, :none})
    |> Trend.add({:work, :small})
    |> Trend.add({:work, :none})
    |> Trend.add({:work, :small}) #
    |> Trend.add({:work, :small})
    |> Trend.add({:work, :small})
    |> Trend.add({:work, :none})
    |> Trend.add({:work, :small}) #
    |> Trend.add({:work, :none})
    |> Trend.add({:work, :none})
    |> Trend.add({:work, :none})
    |> Trend.add({:work, :big}) #
    |> Trend.to_list

    assert list == [{8, 0, 4}, {8, 0, 4}, {4, 0, 4}, {0, 0, 4}]
  end
end
