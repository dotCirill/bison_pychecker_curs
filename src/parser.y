
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
%define api.push-pull push

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
%token YIELD

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

%token TWOSTAR
%token TWODIR
%token LSHIFT
%token RSHIFT

%token OPASSIGN

%token NAME
%token NUMBER
%token STRING
%token ELLIPSE
%token TRUE
%token FALSE
%token NONE

%token NEWLINE
%token INDENT
%token DEINDENT

%%

main: main_ {printf("Syntax is OK!\n");}
main_: | NEWLINE | NEWLINE program | program
program: stmt | stmt program 
stmt: simple_stmt | compound_stmt

simple_stmt: small_stmt NEWLINE | small_stmt ';' NEWLINE | small_stmt ';' simple_stmt
small_stmt: 
  expr_stmt | del_stmt | pass_stmt | flow_stmt | import_stmt |
  global_stmt | nonlocal_stmt | assert_stmt

expr_stmt: 
  expr_single_opassign | expr_stmt_list
expr_stmt_list:
  test_or_star_expr_list |
  test_or_star_expr_list '=' yield_expr |
  test_or_star_expr_list '=' expr_stmt
expr_single_opassign:   
  atom_expr OPASSIGN yield_expr |
  atom_expr OPASSIGN testlist

del_stmt: DEL exprlist
pass_stmt: PASS
flow_stmt:
   BREAK | CONTINUE | 
   RETURN | RETURN testlist | yield_expr |
   RAISE | RAISE test | RAISE test FROM test

import_stmt: import_as_names | import_from

import_as_names: IMPORT dotted_names_as
dotted_names_as: dotted_name_as | dotted_name_as ',' dotted_names_as | dotted_name_as ','
dotted_name_as: dotted_name | dotted_name AS NAME
dotted_name: NAME | NAME '.' dotted_name

import_from: 
  import_from_start IMPORT '*' |
  import_from_start IMPORT dotted_names_as |
  import_from_start IMPORT '(' dotted_names_as ')'
import_from_start: 
  FROM import_from_dots dotted_name | 
  FROM import_from_dots | 
  FROM dotted_name
import_from_dots: '.' | ELLIPSE | '.' import_from_dots | ELLIPSE import_from_dots 

global_stmt: GLOBAL namelist
nonlocal_stmt: NONLOCAL namelist
assert_stmt: ASSERT testlist

compound_stmt: 
  if_stmt | while_stmt | for_stmt | with_stmt | funcdef | 
  classdef | decorated | try_stmt

decorated: decorators classdef | decorators funcdef
decorators: decorator | decorator decorators
decorator: '@' test NEWLINE

if_stmt:  IF test ':' suite if_elifs if_else
if_elifs: | ELIF test ':' suite if_elifs
if_else: | ELSE ':' suite

while_stmt: WHILE test ':' suite while_else
while_else: if_else

for_stmt: FOR exprlist IN testlist ':' suite for_else
for_else: while_else

except_clause: 
  EXCEPT |
  EXCEPT test |
  EXCEPT test AS NAME 
simple_try_stmt: TRY ':' suite except_clause ':' suite 
try_stmt_tailers: 
  ELSE ':' suite |
  ELSE ':' suite FINALLY ':' suite |
  FINALLY ':' suite
try_stmt: simple_try_stmt | simple_try_stmt try_stmt_tailers


with_stmt: WITH with_itemlist ':' suite

suite: simple_stmt | NEWLINE INDENT program DEINDENT

//////////////////////////
//////////
////////// EXPRESSIONS
//////////
//////////////////////////

test_nocond: or_test | lambdef_nocond

star_expr: '*' expr
double_star_expr: TWOSTAR expr

test: 
  or_test |
  or_test IF or_test ELSE test |
  lambdadef

or_test: and_test | and_test OR or_test

and_test: not_test | not_test AND and_test

not_test: NOT not_test | comparison

comparison: expr comparison_comp_ops
comparison_comp_ops: | comp_op expr comparison_comp_ops
comp_op: EQ | NEQ | LE | GE | LT | GT | IN | NOT IN | IS | IS NOT

// PRIORITY  |, ^, &, << >>, + -, * / // %, +x -x ~x, **, ()
expr: xor_expr | xor_expr '|' expr

xor_expr: and_expr | and_expr '^' xor_expr

and_expr: shift_expr | shift_expr '&' and_expr

shift_expr: arith_expr | arith_expr shift shift_expr
shift: LSHIFT | RSHIFT

arith_expr: term_expr | term_expr arith arith_expr
arith: '+' | '-'

term_expr: factor_expr | factor_expr term_ops term_expr
term_ops: '*' | '/' | TWODIR | '%' | '@'

factor_expr: factor_ops factor_expr | power_expr 
factor_ops: '+' | '-'

power_expr: atom_expr | atom_expr TWOSTAR factor_expr

atom_expr: atom atom_expr_tailers
atom_expr_tailers: | atom_expr_tailer atom_expr_tailers
atom_expr_tailer: 
    '(' arglist ')'
  | '(' ')'
  | '[' subscriptlist ']' 
  | '.' NAME

atom: 
  NAME | NUMBER | strings | 
  TRUE | FALSE | NONE | ELLIPSE |
  '(' yield_expr ')' |
  '(' testlist_comp ')' |
  '[' testlist_comp ']' |
  '{' dictorsetmaker '}' |
  '(' ')' | '[' ']' | '{' '}'


strings: STRING | STRING strings

yield_expr: YIELD | YIELD yield_arg
yield_arg: FROM test | testlist

//////////////////////////
//////////
////////// LISTS
//////////
//////////////////////////

arglist: argument | argument ',' | argument ',' arglist
argument:
  test          |
  test comp_for |
  test '=' test |
  TWOSTAR test  |
  '*' test

subscriptlist: subscript | subscript ',' | subscript ',' subscriptlist
mb_test: | test
mb_sliceop: | ':' mb_test
subscript:
  test |
  mb_test ':' mb_test mb_sliceop

exprlist: expr_mb_with_star | expr_mb_with_star ',' | expr_mb_with_star ',' exprlist
expr_mb_with_star: expr | '*' expr

varargslist: 
  vararg | 
  vararg ',' |
  vararg ',' varargslist
vararg: NAME var_arg_mb_eq | '*' | TWOSTAR | '*' NAME | TWOSTAR NAME
var_arg_mb_eq: | '=' test

testlist: test | test ',' | test ',' testlist

test_or_star_expr_list: test_or_star_expr |
                        test_or_star_expr ',' | 
                        test_or_star_expr ',' test_or_star_expr_list
test_or_star_expr: test | star_expr

// for dictionary
test_colon_test_or_double_star_expr_list: test_colon_test_or_double_star_expr |
                               test_colon_test_or_double_star_expr ',' |
                               test_colon_test_or_double_star_expr ',' test_colon_test_or_double_star_expr_list

test_colon_test: test ':' test
test_colon_test_or_double_star_expr: test_colon_test | double_star_expr                      

namelist: NAME | NAME ',' namelist

with_item: test | test AS expr
with_itemlist: with_item | with_item ',' with_itemlist

testlist_comp: test_or_star_expr comp_for | test_or_star_expr_list

dictorsetmaker: 
  dictmaker | setmaker

dictmaker:
  test_colon_test_or_double_star_expr_list |
  test_colon_test comp_for

setmaker: 
  test_or_star_expr_list |
  test_or_star_expr comp_for

//////////////////////////
//////////
////////// COMPREHENSION
//////////
//////////////////////////

comp_iter: comp_for | comp_if
comp_for: FOR exprlist IN or_test | FOR exprlist IN or_test comp_iter
comp_if: IF test_nocond | IF test_nocond comp_iter



//////////////////////////
//////////
////////// DEFINITIONS
//////////
/////////////////////////

lambdadef: 
  LAMBDA ':' test |
  LAMBDA varargslist ':' test

lambdef_nocond:
  LAMBDA ':' test_nocond |
  LAMBDA varargslist ':' test_nocond

classdef: 
  CLASS NAME ':' suite |
  CLASS NAME '(' ')' ':' suite |
  CLASS NAME '(' arglist ')' ':' suite

funcdef: 
  DEF NAME '(' ')' ':' suite |
  DEF NAME '(' varargslist ')' ':' suite

%%

void yyerror(const char *s) {
  printf("Error [%d,%d]: %s\n", yylloc.last_line, yylloc.last_column, s);
}
