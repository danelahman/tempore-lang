include
  TimeGrades.Make
    (Delay.Rational)
    (struct
      type delay = Delay.Rational.t

      let suffix = "-rational"
      let numbers = "numbers"
      let step = None
    end)
