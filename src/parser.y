
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

%token NAME
%token NUMBER
%token STRING
%token ELLIPSE
%token TRUE
%token FALSE
%token NONE

%token NEWLINE

%%

main: stmt stmt_more {printf("Syntax is OK!\n");}
stmt_more: | stmt stmt_more
stmt: simple_stmt | compound_stmt

mb_semicolon: | ';'

simple_stmt: small_stmt small_stmt_more mb_semicolon NEWLINE
small_stmt_more: | ';' small_stmt small_stmt_more 
small_stmt: 
  expr_stmt | del_stmt | pass_stmt | flow_stmt | import_stmt |
  global_stmt | nonlocal_stmt | assert_stmt

expr_stmt: 
  test_or_star_expr_list '=' yield_expr |
  test_or_star_expr_list '=' testlist
// todo: add +=, -=, &=, ..., a =a = ..  =a =a 

del_stmt: DEL exprlist
pass_stmt: PASS
flow_stmt:
   BREAK | CONTINUE | 
   RETURN | RETURN testlist | yield_expr |
   RAISE | RAISE test | RAISE test FROM test

import_stmt: BREAK BREAK BREAK

global_stmt: GLOBAL namelist
nonlocal_stmt: NONLOCAL namelist
assert_stmt: ASSERT testlist

compound_stmt: 
  if_stmt | while_stmt | for_stmt | with_stmt | funcdef | 
  classdef | decorated

decorated: BREAK BREAK BREAK

if_stmt:  IF test ':' suite if_elifs if_else
if_elifs: | ELIF test ':' suite if_elifs
if_else: | ELSE ':' test

while_stmt: WHILE test ':' suite while_else
while_else: if_else

for_stmt: FOR exprlist IN testlist ':' suite for_else
for_else: while_else

try_stmt: TRY TRY TRY TRY

with_stmt: WITH with_itemlist ':' suite
funcdef: 
  DEF NAME '(' ')' ':' suite |
  DEF NAME '(' varargslist ')' ':' suite


suite: simple_stmt | // TODO

//////////////////////////
//////////
////////// EXPRESSIONS
//////////
//////////////////////////

test_nocond: or_test | lambdef_nocond

star_expr: '*' expr

test: 
  or_test |
  or_test IF or_test ELSE test |
  lambdadef

or_test: and_test or_test_ors
or_test_ors: | OR or_test or_test_ors

and_test: not_test and_test_ands
and_test_ands: | AND and_test and_test_ands

not_test: NOT not_test | comparison

comparison: expr comparison_comp_ops
comparison_comp_ops: | comp_op expr comparison_comp_ops
comp_op: EQ | NEQ | LE | GE | LT | GT | IN | NOT IN | IS | IS NOT

// PRIORITY  |, ^, &, << >>, + -, * / // %, +x -x ~x, **, ()
expr: xor_expr expr_ors
expr_ors: | '|' xor_expr expr_ors

xor_expr: and_expr xor_expr_xors
xor_expr_xors: | '^' and_expr xor_expr_xors

and_expr: shift_expr and_expr_ands
and_expr_ands: | '&' shift_expr and_expr_ands

shift_expr: arith_expr shift_expr_shifts
shift_expr_shifts: | shift arith_expr shift_expr_shifts
shift: LSHIFT | RSHIFT

arith_expr: term_expr arith_expr_ariths
arith_expr_ariths: | arith term_expr arith_expr_ariths
arith: '+' | '-'

term_expr: factor_expr term_expr_ops
term_expr_ops: | term_ops factor_expr term_expr_ops
term_ops: '*' | '/' | TWODIR | '%' | '@'

factor_expr: factor_ops factor_expr | power_expr 
factor_ops: '+' | '-'

power_expr: atom_expr | atom_expr TWOSTAR factor_expr

atom_expr: atom atom_expr_tailers
atom_expr_tailers: | atom_expr_tailer atom_expr_tailers
atom_expr_tailer: 
     '(' arglist ')' 
  | '[' subscriptlist ']' 
  | '.' NAME

atom: 
  NAME | NUMBER | STRING atom_strings_zero_or_more | 
  TRUE | FALSE | NONE | ELLIPSE |
  '(' yield_expr ')' |
  '(' testlist_comp ')' |
  '[' testlist_comp ']' |
  '(' ')' | '[' ']' | '{' '}'
  // todo list comp, dict comp, generator comp


atom_strings_zero_or_more: | STRING atom_strings_zero_or_more

yield_expr: YIELD | YIELD yield_arg
yield_arg: FROM test | testlist

//////////////////////////
//////////
////////// LISTS
//////////
//////////////////////////

mb_comma: | ','

arglist: argument arglist_more
arglist_more: | ',' arglist arglist_more
argument:  test
  /* test |
  test comp_for |
  test '=' test |
  TWOSTAR test  |
  '*' test */

subscriptlist: subscript subscriptlist_more mb_comma
subscriptlist_more: | ',' subscript subscriptlist_more
mb_test: | test
mb_sliceop: | ':' mb_test
subscript:
  test |
  mb_test ':' mb_test mb_sliceop

exprlist: expr_mb_with_star exprlist_more mb_comma
exprlist_more: | ',' expr_mb_with_star
expr_mb_with_star: expr | '*' expr

varargslist: 
  vararg | 
  vararg ',' varargslist |
  vararg_args varargslist_kwargs_with_comma_mb mb_comma | 
  vararg_kwargs mb_comma
vararg: NAME var_arg_mb_eq
vararg_args: '*' NAME
vararg_kwargs: TWOSTAR NAME
var_arg_mb_eq: | '=' test
varargslist_kwargs_with_comma_mb: | ',' vararg_kwargs

testlist: test testlist_more mb_comma
testlist_more: | ',' test testlist_more

test_or_star_expr_list: test_or_star_expr |
                        test_or_star_expr ',' | 
                        test_or_star_expr ',' test_or_star_expr_list
test_or_star_expr: test | star_expr

namelist: NAME namelistmore
namelistmore: | ',' NAME namelistmore

with_item: test | test AS expr
with_itemlist: with_item with_items_more
with_items_more: | ',' with_item with_items_more


testlist_comp: test_or_star_expr comp_for | test_or_star_expr_list

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
  CLASS NAME classdef_bracket ':' suite |
classdef_bracket: | '(' classdef_in_bracket ')'
classdef_in_bracket: | arglist

%%

void yyerror(const char *s) {
  printf("Error [%d,%d]: %s\n", yylloc.last_line, yylloc.last_column, s);
}
