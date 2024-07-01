module Symphony
  abstract class BackgroundService
    abstract def start : Nil
    abstract def interrupt : Nil
    abstract def join(timeout : Time::Span? = nil) : Nil
    abstract def alive? : Bool

    # Provided for convenience when composing one service out of another.
    # Takes care of delegating all necessary methods.
    macro service_implemented_by(service)
      def start : Nil
        {{service}}.start
      end

      def interrupt : Nil
        {{service}}.interrupt
      end

      def join(timeout : Time::Span? = nil) : Nil
        {{service}}.join(timeout)
      end

      def alive? : Bool
        {{service}}.alive?
      end
    end
  end
end
