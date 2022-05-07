%{
  #include <stdio.h>
  #include "parser.h"
  int yylex();
  void yyerror(const char *s);
  int isatty(int fd) { return 0; }

  static void update_loc(){
    static int curr_line = 1;
    static int curr_col  = 1;

    yylloc.first_line   = curr_line;
    yylloc.first_column = curr_col;

    {char * s; for(s = yytext; *s != '\0'; s++){
      if(*s == '\n'){
        curr_line++;
        curr_col = 1;
      } else{
        curr_col++;
      }
    }}

    yylloc.last_line   = curr_line;
    yylloc.last_column = curr_col-1;
}

#define YY_USER_ACTION update_loc();

%}

%option noyywrap nounistd yylineno outfile="scanner.c" header="scanner.h"

%%

lambda {
    return LAMBDA;
}

def {
    return DEF;
}

del {
    return DEL;
}

pass {
    return PASS;
}

class {
    return CLASS;
}

import {
    return IMPORT;
}

from {
    return FROM;
}

as {
    return AS;
}

global {
    return GLOBAL;
}

nonlocal {
    return NONLOCAL;
}

if {
    return IF;
}

elif {
    return ELIF;
}

else {
    return ELSE;
}

while {
    return WHILE;
}

for {
    return FOR;
}

break {
    return BREAK;
}

continue {
    return CONTINUE;
}

return {
    return RETURN;
}

try {
    return TRY;
}

except {
    return EXCEPT;
}

finally {
    return FINALLY;
}

raise {
    return RAISE;
}

assert {
    return ASSERT;
}

with {
    return WITH;
}

"==" {
    return EQ;
}

"<=" {
    return LE;
}

">=" {
    return GE;
}

"<" {
    return LT;
}

">" {
    return GT;
}

"!=" {
    return NEQ;
}

not {
    return NOT;
}

in {
    return IN;
}

is {
    return IS;
}

and {
    return AND;
}

or {
    return OR;
}

[ \t]+ {
    // TODO: Something with Ident
}

[\r] {
   // ignore 
}

#.* {
    // comment
}

. {
    return yytext[0];
}

%%

int main(int argc, char **argv)
{
  return yyparse();
}
