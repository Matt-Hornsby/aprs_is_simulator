defmodule AprsIsSimulator.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    port =
      String.to_integer(System.get_env("PORT") || raise("missing $PORT environment variable"))

    children = [
      {Task.Supervisor, name: AprsIsSimulator.TaskSupervisor},
      Supervisor.child_spec({Task, fn -> AprsIsSimulator.accept(port) end}, restart: :permanent)
    ]

    opts = [strategy: :one_for_one, name: AprsIsSimulator.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
