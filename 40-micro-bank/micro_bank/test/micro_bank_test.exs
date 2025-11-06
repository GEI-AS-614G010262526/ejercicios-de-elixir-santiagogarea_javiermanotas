defmodule MicroBankTest do
  use ExUnit.Case
  doctest MicroBank

  setup %{} do
    Application.ensure_started(:micro_bank)

    on_exit(fn -> Application.stop(:micro_bank) end)
  end

  @example_account "EN-444-555555"

  test "not created account" do
    assert MicroBank.ask(@example_account) == 0
  end

  test "deposit money" do
    assert MicroBank.ask(@example_account) == 0
    MicroBank.deposit(@example_account, 1500)
    assert MicroBank.ask(@example_account) == 1500
  end

  test "success withdraw" do
    MicroBank.deposit(@example_account, 3000)
    MicroBank.withdraw(@example_account, 500)
    assert MicroBank.ask(@example_account) == 2500
  end

  test "failed withdraw" do
    MicroBank.deposit(@example_account, 10000)
    assert MicroBank.withdraw(@example_account, 999999) == :not_enough_salary
    assert MicroBank.ask(@example_account) == 10000
  end

  test "process revives" do
    pid = GenServer.whereis(MicroBank)
    Process.exit(pid, :kill)
    assert Process.alive?(pid) == false

    # process might take some time to be alive
    :timer.sleep(100)
    assert MicroBank.ask(@example_account) == 0
  end

end
