defmodule Hound.Helpers.Screenshot do
  @moduledoc "Provides helper function to take screenshots"

  import Hound.RequestUtils

  @doc """
  Takes screenshot of the current page. The screenshot is saved in the current working directory.
  It returns the path of the png file, to which the screenshot has been saved.

  For Elixir mix projects, the saved screenshot can be found in the root of the project directory.

      take_screenshot()

  You can also pass a file path to which the screenshot must be saved to.

      # Pass a full file path
      take_screenshot("/media/screenshots/test.png")

      # Or you can also pass a path relative to the current directory.
      take_screenshot("screenshot-test.png")
  """
  @spec take_screenshot(String.t) :: String.t
  def take_screenshot(path \\ nil) do
    session_id = Hound.current_session_id
    base64_png_data = make_req(:get, "session/#{session_id}/screenshot")

    binary_image_data = :base64.decode(base64_png_data)
    {hour, minutes, seconds} = :erlang.time()
    {year, month, day} = :erlang.date()

    if !path do
      cwd = File.cwd!()
      path = "#{cwd}/screenshot-#{year}-#{month}-#{day}-#{hour}-#{minutes}-#{seconds}.png"
    end
    :ok = File.write path, binary_image_data
    path
  end

  def take_screenshot_for_session_and_host(session_id, host, driver_info, path \\ nil) do
    base64_png_data = make_req(:get, "session/#{session_id}/screenshot", %{}, %{custom_selenium_host: host, driver_info: driver_info})

    binary_image_data = :base64.decode(base64_png_data)
    {hour, minutes, seconds} = :erlang.time()
    {year, month, day} = :erlang.date()

    if !path do
      cwd = File.cwd!()
      path = "#{cwd}/screenshot-#{year}-#{month}-#{day}-#{hour}-#{minutes}-#{seconds}.png"
    end
    :ok = File.write path, binary_image_data
    path
  end

  def take_raw_screenshot_for_session_and_host(session_id, host, driver_info, path \\ nil) do
    base64_png_data = make_req(:get, "session/#{session_id}/screenshot", %{}, %{custom_selenium_host: host, driver_info: driver_info})

    :base64.decode(base64_png_data)
  end
end
