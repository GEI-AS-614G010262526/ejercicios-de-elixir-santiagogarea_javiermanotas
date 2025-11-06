defmodule MicroBank do

  use GenServer

  def start_link(_default) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def deposit(who, amount) do
    GenServer.cast(__MODULE__, {:deposit, who, amount})
  end

  def ask(who) do
    GenServer.call(__MODULE__, {:ask, who})
  end

  def withdraw(who, amount) do
    GenServer.call(__MODULE__, {:withdraw, who, amount})
  end

  def stop() do
    GenServer.stop(__MODULE__)
  end

  @impl true
  def init(_arg) do
    IO.puts("started")
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:deposit, who, amount}, state) do
    {:noreply, Map.update(state, who, amount, fn x -> x + amount end)}
  end

  @impl true
  def handle_call({:ask, who}, _from, state) do
    {:reply, Map.get(state, who, 0), state}
  end

  @impl true
  def handle_call({:withdraw, who, amount}, _from, state) do
    if Map.get(state, who, 0) >= amount do
      {:reply, :ok, Map.update(state, who, 0, fn x -> x - amount end)}
    else
      {:reply, :not_enough_salary, state}
    end
  end
end
