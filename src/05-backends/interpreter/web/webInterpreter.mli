module SyntaxHighlight = SyntaxHighlight

module Make (ResourceGrade : Language.Grade.S) :
  WebBackend.S with module ResourceGrade = ResourceGrade
