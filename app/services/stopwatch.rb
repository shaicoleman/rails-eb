class Stopwatch
  def initialize
    @start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def elapsed
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - @start
  end
end
