defmodule Mix.Tasks.PhoenixStarter.Gen.PageMetaTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.PhoenixStarter.Gen.PageMeta

  describe "phoenix_starter.gen.page_meta" do
    test "declares phoenix_page_meta as an install" do
      info = PageMeta.info([], nil)

      assert {:phoenix_page_meta, "~> 0.1"} in info.installs
    end
  end
end
