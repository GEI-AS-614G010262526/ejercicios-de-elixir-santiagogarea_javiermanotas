defmodule MicroBank.Application do
  use Application

  @impl true
  def start(_start_type, _start_args) do


    children = [
      %{
        id: MicroBank,
        start: {MicroBank, :start_link, [:any]}
      }
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  @impl true
  def stop(_state) do
    Supervisor.terminate_child(__MODULE__, MicroBank)
    Supervisor.delete_child(__MODULE__, MicroBank)
    Supervisor.stop(__MODULE__, :normal)
  end
end
