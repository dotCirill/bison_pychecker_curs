
%code {
  #include <stdio.h>

  int yylex();
  void yyerror(const char *s);
  int yylineno;
}

%defines "parser.h"
%output "parser.c"

%locations
%define parse.error verbose

%token LAMBDA
%token DEF
%token DEL
%token PASS
%token CLASS

%token IMPORT
%token FROM
%token AS

%token GLOBAL
%token NONLOCAL

%token IF
%token ELIF
%token ELSE

%token WHILE
%token FOR
%token BREAK
%token CONTINUE
%token RETURN

%token TRY
%token EXCEPT
%token FINALLY
%token RAISE
%token ASSERT

%token WITH

%token EQ
%token LE
%token GE
%token LT
%token GT
%token NEQ
%token NOT
%token IN
%token IS

%token AND
%token OR

%union {
  int int_value;
}


%%  

main: FINALLY TRY BREAK OR PASS WITH LAMBDA

%%

void yyerror(const char *s) {
  printf("Error [%d,%d]: %s\n", yylloc.last_line, yylloc.last_column, s);
}
