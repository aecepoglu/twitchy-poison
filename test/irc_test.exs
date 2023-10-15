defmodule IRC.BadgeTest do
  use ExUnit.Case
  import IRC.Badge

  @badge "@badge-info=;badges=broadcaster/1;client-nonce=59c0d643fd7086a8fede4901ae97795e;color=#D2691E;display-name=WhimsicalLyMade;emotes=;first-msg=0;flags=;id=2c69c055-4c23-4271-a20e-edc223e5537a;mod=0;returning-chatter=0;room-id=818716685;subscriber=0;tmi-sent-ts=1697387897918;turbo=0;user-id=818716685;user-type="

  test "parse" do
    assert Map.new(parse(@badge))
      ==
      Map.new([name: "WhimsicalLyMade", color: "\e[38;2;210;105;30m", returning: false, first: false])
  end
end
