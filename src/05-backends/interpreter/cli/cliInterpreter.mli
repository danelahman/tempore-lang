module Make (ResourceGrade : Language.Grade.S) :
  CliBackend.S with module ResourceGrade = ResourceGrade
