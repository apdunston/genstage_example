# # Upcase the string you start with, and then show a secret that only D knows.

defmodule Example3 do
  @moduledoc """
  This is a finite state machine. It's a simple producer-consumer set up but 
  done in manual mode. I couldn't find examples of handle_subscribe, so I 
  worked it out from the unit tests. 

  Basically to use ask, you need not only the producer's pid, but the reference
  for the subscription. So I had the consumer hold the pid and ref in its state
  and use them when it gets an ask call.
  """

  use Experimental.GenStage
  alias Experimental.GenStage
  
  def go do
    IO.puts "\n\nYou should run this as\n\n{producer, consumer} = Example3.go"
    IO.puts "\nThen you can run\n\nExample3.ask(consumer)\n\nto do a manual request up the GenStage chain\n\n"

    {:ok, producer} = GenStage.start_link(I, :ok)   
    {:ok, consumer} = GenStage.start_link(J, :ok) 

    GenStage.sync_subscribe(consumer, to: producer, max_demand: 100, min_demand: 1)
    {producer, consumer}
  end

  def ask(consumer), do: GenStage.call(consumer, :ask)

end




defmodule I do
  use Experimental.GenStage
  alias Experimental.GenStage

  def init(_) do
    {:producer, 1}
  end

  def handle_demand(demand, 1) when demand > 0 do
    IO.puts "state 1, demand is #{demand}"
    {:noreply, List.duplicate("alpha", demand), 2}
  end

  def handle_demand(demand, 2) when demand > 0 do
    IO.puts "state 2, demand is #{demand}"
    {:noreply, ["bravo"], 3}
  end
  def handle_demand(demand, 3) when demand > 0 do
    IO.puts "state 3, demand is #{demand}"
    {:noreply, [], 4}
  end
  def handle_demand(demand, 4) when demand > 0 do
    IO.puts "state 4, demand is #{demand}"
    {:noreply, ["You win! You've seen all the states. I'm looping back around"], 1}
  end
end







defmodule J do
  use Experimental.GenStage
  alias Experimental.GenStage
  use GenServer

  def init(:ok) do
    {:consumer, :ok}
  end

  def handle_events(events, from, state) do
    # Wait for a second.
    :timer.sleep(50)

    IO.puts(events)
    
    # We are a consumer, so we would never emit items.
    {:noreply, [], state}
  end

  def handle_cancel(reason, from, state) do
    IO.puts "I was cancelled. Stuff below"
    IO.inspect {reason, from, state}
  end

  @doc """
  Set the state to the from {pid, ref} so we can call directly through 
  that subscription.
  """
  def handle_subscribe(consumer_or_producer, opts, from = {_pid, _ref}, state) do
    {:manual, from}
  end

  def handle_call(:ask, from, state) do
    answer = GenStage.ask(state, 1)
    GenStage.reply(from, answer)
    {:noreply, [], state}  
  end

end



