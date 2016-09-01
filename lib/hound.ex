defmodule Hound do
  use Application

  # See http://elixir-lang.org/docs/stable/Application.Behaviour.html
  # for more information on OTP Applications
  @doc false
  def start(_type, _args) do
    Hound.Supervisor.start_link
  end


  @doc false
  def driver_info do
    IO.inspect "HOUND driver_info was called"
    cdi = Hound.Helpers.Session.current_driver_info
    if cdi do
      {:ok, Hound.Helpers.Session.current_driver_info}
    else
      Hound.ConnectionServer.driver_info
    end
  end

  @doc false
  def configs do
    Hound.ConnectionServer.configs
  end


  @doc "See `Hound.Helpers.Session.start_session/1`"
  defdelegate start_session,            to: Hound.Helpers.Session
  defdelegate start_session(opts),      to: Hound.Helpers.Session

  @doc "See `Hound.Helpers.Session.end_session/1`"
  defdelegate end_session,        to: Hound.Helpers.Session
  defdelegate end_session(pid),   to: Hound.Helpers.Session
  defdelegate end_session(pid, driver_info), to: Hound.Helpers.Session

  @doc false
  defdelegate current_session_id, to: Hound.Helpers.Session
end
