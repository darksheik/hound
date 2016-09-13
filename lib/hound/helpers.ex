defmodule Hound.Helpers do
  @moduledoc false

  defmacro __using__([]) do
    quote do
      import Hound
      import Hound.Helpers.Cookie
      import Hound.Helpers.Dialog
      import Hound.Helpers.Element
      import Hound.Helpers.Navigation
      import Hound.Helpers.Orientation
      import Hound.Helpers.Page
      import Hound.Helpers.Screenshot
      import Hound.Helpers.ScriptExecution
      import Hound.Helpers.Session
      import Hound.Helpers.Window
      import unquote(__MODULE__)
    end
  end


  defmacro hound_session do
    quote do
      setup do
        {:ok, driver_info} = Hound.driver_info
        passed_options = %{custom_selenium_host: "localhost", driver_info: driver_info}
        session_id = Hound.start_session(%{}, passed_options)
        parent = self
        on_exit fn->
          Hound.Session.destroy_session(session_id, "localhost", driver_info)
        end
        :ok
      end
    end
  end

end
