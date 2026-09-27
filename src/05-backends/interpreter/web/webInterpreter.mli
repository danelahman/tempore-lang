module SyntaxHighlight = SyntaxHighlight
module Make (GS : Grades.GradeSystem.S) : WebBackend.S with module Grades = GS
