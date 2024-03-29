%{
  #include <stdio.h>
  #include "parser.h"

  yypstate *ps = NULL;
  extern int yychar;
  
  // Expressions in parentheses, 
  // square brackets or curly braces can be split 
  // over more than one physical line without using backslashes. 
  int implicit_line_joining_opened_brackets = 0;

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
    if (indent_info.now_newline && yytext[0] != ' ' && yytext[0] != '\t' && yytext[0] != '\n') {
      zero_indent();
    }
  }

  #define YY_USER_ACTION { check_zero_indent(); update_loc(); }                                                          
  #define CURRENT_LEVEL_INDENT_COUNT (indent_count[indent_info.indent_level])
%}

%option noyywrap nounistd yylineno outfile="scanner.c" header="scanner.h"

NAME ([_a-zA-Z][_a-zA-Z0-9]*)

ESCAPED_CHAR (\\.|\\\n)
STRING_PREFIX ("r"|"u"|"R"|"U"|"f"|"F"|"fr"|"Fr"|"fR"|"FR"|"rf"|"rF"|"Rf"|"RF"|"b"|"B"|"br"|"Br"|"bR"|"BR"|"rb"|"rB"|"Rb"|"RB")
STRING_QUOTE1 ('([^\\'\n]|{ESCAPED_CHAR})*')
STRING_QUOTE2 (\"([^\\\"\n]|{ESCAPED_CHAR})*\")

INSIDE_LONG_QUOTE1 ([']{0,2}([^\\']|{ESCAPED_CHAR}))*
INSIDE_LONG_QUOTE2 ([\"]{0,2}([^\\\"]|{ESCAPED_CHAR}))*
LONG_STRING_QUOTE1 ('''{INSIDE_LONG_QUOTE1}''')
LONG_STRING_QUOTE2 (\"\"\"{INSIDE_LONG_QUOTE2}\"\"\")
STRING_QUOTE ({STRING_PREFIX}?)({STRING_QUOTE1}|{STRING_QUOTE2}|{LONG_STRING_QUOTE1}|{LONG_STRING_QUOTE2})

/* For some reason "000123" is invalid INT10, but "00000" is valid */
INT10 ([1-9](_?[0-9])*)|(0(_?0)*)
INT2 0[bB](_?[01])+
INT8 0[oO](_?[0-7])+
INT16 0[xX](_?[0-9a-fA-F])+
INT ({INT10}|{INT2}|{INT8}|{INT16})

/* For some reason "000123.0" is valid FLOAT */
DIGITS ([0-9](_?[0-9])*)
EXPONENT ([eE][+-]?{DIGITS})
FRACTION \.{DIGITS}
MB_EMPTY_FRACTION \.{DIGITS}?
FLOAT {DIGITS}{MB_EMPTY_FRACTION}{EXPONENT}|{DIGITS}{EXPONENT}|{DIGITS}{MB_EMPTY_FRACTION}|{FRACTION}{EXPONENT}|{FRACTION}

/* For some reason "000123j is valid Complex */
COMPLEX ({FLOAT}|{DIGITS})[jJ]
NUMBER ({INT}|{FLOAT}|{COMPLEX})

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

async {
    return ASYNC;
}

await {
    return AWAIT;
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

\\\n[ \t]* {
    // ignore: Explicit line joining
}

\[|\(|\{ {
    implicit_line_joining_opened_brackets++;
    return yytext[0];
}

\]|\)|\} {
    implicit_line_joining_opened_brackets--;
    return yytext[0];
}

\n*([ \t]*#.*\n)*[ \t]*#.* {
    // newlines at the start >= 0
    // comment with newlines >= 0
    // comment without newline = 1
    // tabs and spaces at the begining are also ignored
}

\n+ {
    if (implicit_line_joining_opened_brackets) {
        YY_BREAK;
    }
    return NEWLINE;
}

[ \t]+ {
    if (!indent_info.prev_newline || implicit_line_joining_opened_brackets) {
        YY_BREAK;
    }
    
    char indent_symbol = indent_info.indent_by_space ? ' ' : '\t';
    int yy_len = strlen(yytext);
    int first_indent = 0;

    if (indent_info.indent_level == 0) {
        indent_symbol = yytext[0];
        indent_info.indent_by_space = indent_symbol == ' ';
        indent_info.indent_level++;
        CURRENT_LEVEL_INDENT_COUNT = yy_len;
        first_indent = 1;
        // we will only check mixing space and tabs
    }

    for (int i = 0; i < yy_len; i++) {
        if (yytext[i] != indent_symbol) {
            yyerror("Invalid indent (mixing space and tabs)!");
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
            yyerror("Fatal error: indent level is negative!\n");
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
