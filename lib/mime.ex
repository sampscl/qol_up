defmodule QolUp.Mime do
  @moduledoc """
  MIME utilities
  """
  def json, do: "application/json"
  def html, do: "text/html"
  def plain_text, do: "text/plain"
end
