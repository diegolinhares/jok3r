defmodule Jok3rWeb.ErrorJSONTest do
  use Jok3rWeb.ConnCase, async: true

  test "renders 404" do
    assert Jok3rWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert Jok3rWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
