%{

  #include "cpq.tab.h"
  #include "symbol_table.h"

  #include <string.h> 
  #include <stdlib.h>

  extern int yylineno;

%}

%option noyywrap

%option yylineno

%x COMMENT
DIGIT [0-9]
LETTER [a-z]
RELOP "=="|"!="|"<"|">"|"<="|">="
PUNCTUATIONS ";"|"="|","|":"|"("|")"|"{"|"}"

%x STAR_COMMENT

/* \"([^\\"\n]|\\\")*\" {  return STRING; } */

%%
<INITIAL>
"if" { return IF; }
"else" { return ELSE; }
"switch" { return SWITCH; }
"case" { return CASE; }
"break" { return BREAK; }
"default" { return DEFAULT; }
"while" { return WHILE; }
"input" { return INPUT; }
"output" { return OUTPUT; }

"int" { return INT; }
"float" { return FLOAT; }

"cast<<int>>" { 
  yylval.type = TYPE_INT;
  return CAST; }

"cast<<float>>" { 
  yylval.type = TYPE_FLOAT;
  return CAST; }

[+-] { yylval.op = yytext[0]; return ADDOP; }
[*/] { yylval.op = yytext[0]; return MULOP; }

[!] { return NOT; }
"||" { return OR; }
"&&" { return AND; }

{RELOP} { 
  if(!strcmp(yytext,"==")){
    yylval.relop = RELOP_EQ;
  } else if (!strcmp(yytext,"!=")) {
    yylval.relop = RELOP_NE;
  } else if(!strcmp(yytext,"<")) {
    yylval.relop = RELOP_LT; 
  } else if(!strcmp(yytext,">")) {
    yylval.relop = RELOP_GT;
  } else if(!strcmp(yytext,"<=")) {
    yylval.relop = RELOP_LE;
  } else if(!strcmp(yytext,">=")) {
    yylval.relop = RELOP_GE;
  }
  return RELOP;}

{PUNCTUATIONS} { return yytext[0]; }

{DIGIT}+"."{DIGIT}* 	{ 
  yylval.num.type = TYPE_FLOAT; 
  yylval.num.value.fval = (float)atof(yytext); 
  return NUM; 
}

{DIGIT}+ { 
  yylval.num.type = TYPE_INT; 
  yylval.num.value.ival = (int)atoi(yytext); 
  return NUM; 
}

({LETTER}|_)({LETTER}|{DIGIT}|_)*	{ yylval.sval = strdup(yytext); return ID; }

[\t\r ]+  { /* skip white space */ }

[\n]+       {  }
                                         			 
"//"       { BEGIN (COMMENT); }

<COMMENT>.+ { /* skip comment */ }
<COMMENT>\n {  /* end of comment --> resume normal processing */
                BEGIN (0); }
				
"/*"  { BEGIN(STAR_COMMENT); }
				
<STAR_COMMENT>{
[^*\n]+    { /* skip chars in comment */ }

"*"+"/"  { BEGIN(0); }  // better
[\n]+     {  }
"*"+    { /* skip  '*' s. (if the '*' is followed by a slash -- the
            next rule will handle it) */ } 
} // end STAR_COMMENT

.          { fprintf (stderr, "line %d: unrecognized token %c(%x)\n", 
                               yylineno, yytext[0], yytext[0]); }
							   
%%