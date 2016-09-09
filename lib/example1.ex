defmodule Example1 do
  @moduledoc """
  Makes some pretty console output as the producer streams out characters 
  and the consumer prints upcased versions of the characters.
  """
  use Experimental.GenStage
  alias Experimental.GenStage
  
  def go do
    start_string = "I am the very model of a modern major general."

    {:ok, producer} = GenStage.start_link(A, start_string) # distribute and puts
    {:ok, midstep} = GenStage.start_link(B, :ok)           # upcase
    {:ok, consumer} = GenStage.start_link(C, :ok)          # collect and puts

    GenStage.sync_subscribe(consumer, to: midstep, max_demand: 1)
    GenStage.sync_subscribe(midstep, to: producer, max_demand: 1)
  end

end


defmodule A do
  @moduledoc """
  Producer
  Only handles a demand of 1.
  It takes an input string at init. It deals out that string one character at a
  time. Once it's out of characters, it sends :done.
  """
  use Experimental.GenStage

  @doc "Set the state to whatever's passed in."
  def init(string) do
    {:producer, string}
  end

  @doc """
  If the state gets flipped to :done, send :done and flip it to [].
  There's no reason for this, really. I just wanted to play around with 
  `handle_demand` in different contexts.
  """
  def handle_demand(demand, [:done]) when demand == 1 do
    {:noreply, [:done], :not_a_string_and_not_the_done_atom}
  end


  def handle_demand(demand, string) when demand == 1 and is_bitstring(string) do
    IO.puts string
    [events, string] = split_string(string, demand)
    {:noreply, events, string_or_done(string)}
  end

  @doc """
  Catchall. Sending [] as events breaks the subscription. Basically sending
  any list of events < the demand will break the subscription. Note that if you
  send [:done] here instead of [], the consumer will never stop. It will just
  keep cheering about being done forever.
  """
  def handle_demand(demand, anything_else) when demand > 0 do
    {:noreply, [], :it_doesnt_matter_because_empty_set_will_stop_the_subscription}
  end


  def string_or_done(""), do: [:done]
  def string_or_done(string), do: string

  defp split_string(string, position),
    do: [
      front(string, position), 
      back(string, position)
    ]

  defp front(string, position),
    do: string |> String.slice(0, position) |> String.to_charlist

  defp back(string, position),
    do: String.slice(string, position, String.length(string)) 
end


defmodule B do
  @moduledoc """
  Producer_Consumer
  Take a charlist or string, upcase it, and hand it out as a charlist.
  If you get :done, pass it along.
  """
  use Experimental.GenStage

  def init(:ok) do
    {:producer_consumer, :ok}
  end
  
  def handle_events([:done], from, state) do 
    {:noreply, [:done], state}
  end
  
  def handle_events(events, from, state) do
    events = events |> to_string |> String.upcase |> String.to_charlist
    {:noreply, events, state}
  end
end



defmodule C do
  @moduledoc """
  Consumer
  If you get :done, brag about it. Otherwise, throw the character into your
  state, and puts that state for the world to see.
  """
  use Experimental.GenStage

  def init(:ok) do
    {:consumer, ""}
  end

  def handle_events([:done], _from, state) do
    IO.puts "I GOT DONE! :)"
    {:noreply, [], state}
  end

  def handle_events(events, _from, state) do
    # Wait for a second.
    :timer.sleep(100)

    state = state <> to_string(events)
    IO.puts state

    # We are a consumer, so we would never emit items.
    {:noreply, [], state}
  end

end
