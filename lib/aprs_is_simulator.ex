require Logger

defmodule AprsIsSimulator do
  @heartbeat_timeout 20000
  @message_send_rate 1

  def accept(port) do
    {:ok, socket} =
      :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])

    Logger.info("Accepting connections on port #{port}")
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    Logger.info "Client connected: #{inspect client}"
    {:ok, fp} = File.open("priv/data.txt")

    {:ok, pid} =
      Task.Supervisor.start_child(AprsIsSimulator.TaskSupervisor, fn -> serve(client, fp) end)

    :ok = :gen_tcp.controlling_process(client, pid)
    schedule_heartbeat(pid, @heartbeat_timeout)
    schedule_message_send(pid, @message_send_rate)

    Process.send_after(pid, [:send_login_message], 500)
    loop_acceptor(socket)
  end

  defp serve(socket, file) do
    receive do
      [:send_login_message] ->
        write_line("# Logged in\r\n", socket)
        serve(socket, file)

      [:send_heartbeat] ->
        write_line("# HEART BEAT\r\n", socket)
        schedule_heartbeat(self(), @heartbeat_timeout)
        serve(socket, file)

      [:send_next_message] ->
        input = IO.read(file, :line)

        input =
          case input do
            :eof ->
              # It's unsafe to open a file like this inside a case
              # but i haven't figured out a better way yet.
              Logger.info("Reached end of file. Starting from beginning")
              result = File.close(file)
              Logger.debug "#{result}"
              {:ok, file} = File.open("priv/short.txt")
              Logger.debug "#{result}"
              IO.read(file, :line)
            _ ->
              input
          end

        write_line(input, socket)
        schedule_message_send(self(), :rand.uniform(@message_send_rate))
        serve(socket, file)

      msg ->
        Logger.warn("Received unknown message #{inspect(msg)}")
    end
  end

  defp schedule_heartbeat(pid, timeout) do
    Process.send_after(pid, [:send_heartbeat], timeout)
  end

  defp schedule_message_send(pid, rate) do
    Process.send_after(pid, [:send_next_message], rate)
  end

  defp write_line(line, socket) do
    :gen_tcp.send(socket, line)
  end
end
