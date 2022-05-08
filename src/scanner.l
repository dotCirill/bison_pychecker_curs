%{
  #include <stdio.h>
  #include "parser.h"

  yypstate *ps = NULL;
  extern int yychar;

  static int push_token(int token) {
    static int last_was_newline = 0;
    if (token == NEWLINE && last_was_newline) {
      return YYPUSH_MORE;
    }

    last_was_newline = token == NEWLINE;
    yychar = token;
    return yypush_parse(ps);
  }

  int custom_input(char *buf);
  #define YY_INPUT(buf, result, maxsize) result = custom_input(buf);

  int yylex();
  void yyerror(const char *s);
  int isatty(int fd) { return 0; }

  #define MAX_indent_LEVEL 100
  int indent_count[MAX_indent_LEVEL] = {0}; // count of indent-symbols on i indent level

  static struct {
    int prev_newline;
    int now_newline;
    int indent_by_space; // else indent by tabs
    int indent_level; // index in indent_count
  } indent_info = {0};

  static void update_loc () {
    static int curr_line = 1;
    static int curr_col  = 1;

    yylloc.first_line   = curr_line;
    yylloc.first_column = curr_col;
    indent_info.prev_newline = indent_info.now_newline;

    for (char *s = yytext; *s != '\0'; s++) {
      if (*s == '\n') {
        curr_line++;
        curr_col = 1;
        indent_info.now_newline = 1;
      } else {
        curr_col++;
        indent_info.now_newline = 0;
      }
    }

    yylloc.last_line   = curr_line;
    yylloc.last_column = curr_col-1;
  }

  static void zero_indent() {
    while (indent_info.indent_level) {
      indent_info.indent_level--;
      push_token(DEINDENT);
    }
  }

  static void check_zero_indent() {
    if (indent_info.now_newline && yytext[0] != ' ' && yytext[0] != '\t') {
      zero_indent();
    }
  }

  #define YY_USER_ACTION { check_zero_indent(); update_loc(); }                                                          
  #define CURRENT_LEVEL_INDENT_COUNT (indent_count[indent_info.indent_level])
%}

%option noyywrap nounistd yylineno outfile="scanner.c" header="scanner.h"

NAME ([_a-zA-Z][_a-zA-Z0-9]*)
ESCAPED_CHAR (\\.|\\\n)
STRING_QUOTE2 (\"([^\\\"]|{ESCAPED_CHAR})*\")
STRING_QUOTE ({STRING_QUOTE2})
NUMBER ([0-9]+)

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

yield {
    return YIELD;
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

"**" {
    return TWOSTAR;
}

"//" {
    return TWODIR;
}

"<<" {
    return LSHIFT;
}

">>" {
    return RSHIFT;
}


"+="|"-="|"*="|"@="|">>="|"<<="|"&="|"|="|"//="|"/="|"%="|"**="|"\^=" {
    return OPASSIGN;
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

{NAME} {
    return NAME;
}

\.\.\. {
    return ELLIPSE;
}

{NUMBER} {
    return NUMBER;
}

{STRING_QUOTE} {
    return STRING;
}

<<EOF>> {
    push_token(NEWLINE);
    zero_indent();
    return YY_NULL;
}

\n+ {
    return NEWLINE;
}

[ \t]+ {
    if (!indent_info.prev_newline) {
        YY_BREAK;
    }
    
    char indent_symbol = indent_info.indent_by_space ? ' ' : '\t';
    int yy_len = strlen(yytext);
    int first_indent = 0;

    if (indent_info.indent_level == 0) {
        indent_symbol = yytext[0];
        indent_info.indent_level++;
        CURRENT_LEVEL_INDENT_COUNT = yy_len;
        first_indent = 1;
        // we will only check mixing space and tabs
    }

    for (int i = 0; i < yy_len; i++) {
        if (yytext[i] != indent_symbol) {
            printf("Invalid indent (mixing space and tabs)!\n");
            exit(0);
        }
    }

    if (first_indent) {
        return INDENT;
    }

    if (yy_len > CURRENT_LEVEL_INDENT_COUNT) {
        if (indent_info.indent_level >= MAX_indent_LEVEL - 1) {
            printf("MAX_indent_LEVEL = %d is reached!", MAX_indent_LEVEL);
            exit(0);
        }

        indent_info.indent_level++;
        CURRENT_LEVEL_INDENT_COUNT = yy_len;
        return INDENT;
    } else {
      while (yy_len < CURRENT_LEVEL_INDENT_COUNT) {
        indent_info.indent_level--;
        if (indent_info.indent_level < 0) {
            printf("Fatal error: indent level is negative!\n");
            exit(1);
        }

        push_token(DEINDENT);
      }
      // yy_len >= CURRENT_LEVEL_INDENT_COUNT here
      if (yy_len > CURRENT_LEVEL_INDENT_COUNT) {
        printf("Invalid indent (it should be %d to deindent)\n", CURRENT_LEVEL_INDENT_COUNT);
        exit(0);
      }
    }
}

[\r] {
   // ignore 
}

#.*\n {
    // comment
}

. {
    return yytext[0];
}

%%

static char *file_buffer = 0;
static int file_buffer_size = 0;

int custom_input(char *buf) {
  static int file_buffer_i = 0;
  if (file_buffer_i < file_buffer_size) {
    buf[0] = file_buffer[file_buffer_i];
    file_buffer_i++;
    return 1;
  } 

  return YY_NULL;
}

int main(int argc, char **argv) {
  if (argc != 2) {
    printf("Valid usage: <program> <.py>\n");
    exit(1);
  }

  FILE *file = fopen(argv[1], "r");
  if (!file) {
    printf("File not found!\n");
    exit(1);
  }

  fseek(file, 0L, SEEK_END);
  file_buffer_size = ftell(file);
  rewind(file);
  file_buffer = (char*) malloc(file_buffer_size);
  fread(file_buffer, 1, file_buffer_size, file);

  int status;
  ps = yypstate_new();
  
  do {
    status = push_token(yylex());
  } while (status == YYPUSH_MORE);
  
  yypstate_delete (ps);
}
