begin
  require 'curses'
rescue LoadError
  raise "To use CursedPrinter you need to add a 'curses' gem to your project"
end

module Gana
  class CursedPrinter
    include Curses

    def initialize(runner)
      @runner = runner
      @thread = Thread.new { run }
    end

    STATEMENT_SPINNER = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.freeze
    RUNNING_SPINNER = '◴◵◶◷◴◵◶◷◴◵◶◷'.freeze
    SUCCESS_MARK = '✔'.freeze
    FAIL_MARK = '✘'.freeze
    PRINT_MARK = 'ℹ'.freeze

    GREEN = 1
    RED = 2
    YELLOW = 3
    WHITE = 4
    BLACK = 5
    BLUE = 6
    MAGENTA = 7

    def run
      setup

      @running_statements = Hash.new { |h, k| h[k] = -1 }
      @running_time = -1
      while redraw
        sleep 0.07
      end

      redraw
      getch
    ensure
      close_screen
    end

    def finalize
      @thread.join
    ensure
      close_screen
    end

    private

    def setup
      init_screen
      setup_colors
      curs_set(0)
    end

    def setup_colors
      start_color
      init_pair(GREEN, COLOR_GREEN, COLOR_BLACK)
      init_pair(RED, COLOR_RED, COLOR_BLACK)
      init_pair(YELLOW, COLOR_YELLOW, COLOR_BLACK)
      init_pair(WHITE, COLOR_WHITE, COLOR_BLACK)
      init_pair(BLACK, COLOR_BLACK, COLOR_BLACK)
      init_pair(BLUE, COLOR_BLUE, COLOR_BLACK)
      init_pair(MAGENTA, COLOR_MAGENTA, COLOR_BLACK)
    end

    def redraw
      @x, @y = 0, 0
      @runner.log.each do |entry|
        case entry
        when Statement
          case entry.status
          when :running
            index = @running_statements[entry] += 1
            clr(YELLOW) { pr STATEMENT_SPINNER[index % STATEMENT_SPINNER.length] }
          when :failed
            clr(RED) { pr FAIL_MARK }
          when :succeed
            clr(GREEN) { pr SUCCESS_MARK }
          end
          pr_worker_mark(entry.worker)
          clr(WHITE, bold: true) { pr " #{entry.sql}" }
          clr(BLUE) { pr sprintf(' (%0.6fs)', entry.duration) } if entry.duration
          br
        when LogError
          e = entry.error
          clr(RED) { pr FAIL_MARK }
          pr_worker_mark(entry.worker)
          clr(WHITE, bold: true) { pr " #{e.inspect}"; br }
          clr(WHITE) do
            e.backtrace.each do |line|
              break if line =~ %r{lib/gana/worker\.rb}
              pr("   #{line}"); br
            end
          end
        when LogPrint
          clr(WHITE, bold: true ) { pr PRINT_MARK }
          pr_worker_mark(entry.worker)
          clr(WHITE) { pr " #{entry.msg}"; br }
        end
      end
      @runner.workers.any?(&:alive?).tap do |running|
        if running
          index = @running_time += 1
          clr(WHITE, bold: true) do
            pr '〔 '
            n = RUNNING_SPINNER.length
            forward = (index.div n).even?
            index = (index.modulo n)
            spc = if forward
                    index + 1
                  else
                    n - index + 1
                  end
            pr (' ' * spc)
            pr RUNNING_SPINNER[index]
            pr (' ' * (n-spc + 1))
            pr ' 〕'
          end
        else
          br; clr(WHITE) { pr "Press any key..." }
        end
        br
        refresh
      end
    end

    def pr_worker_mark(worker)
      return unless worker
      clr(MAGENTA) { pr " (T#{worker.index + 1})" }
    end

    def clr(color, bold: false)
      attr = color_pair(color)
      attr |= A_BOLD if bold
      attron(attr)
      yield
    ensure
      attroff(attr)
    end

    def pr(str)
      return if str.empty?
      setpos(@y, @x)
      addstr(str)
      @x += str.length % cols
      @y += str.length / cols
    end

    def br
      setpos(@y, @x)
      clrtoeol
      @x = 0
      @y += 1
    end
  end
end
