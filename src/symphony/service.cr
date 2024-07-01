module Symphony
  abstract class BackgroundService
    abstract def start : Nil
    abstract def interrupt : Nil
    abstract def join(timeout : Time::Span? = nil) : Nil
    abstract def alive? : Bool
  end
end
