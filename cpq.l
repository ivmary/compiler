%{

  #include "cpq.tab.h"
  #include "symbol_table.h"

  #include <string.h> 
  #include <stdlib.h>

  extern int yylineno;

// extern int atoi (const char *);
%}

%option noyywrap

%option yylineno

%x COMMENT
DIGIT [0-9]
LETTER [a-z]
PUNCTUATIONS ";"|"="|","|":"|"("|")"|"{"|"}"

%x STAR_COMMENT

/* \"([^\\"\n]|\\\")*\" {  return STRING; } */

%%
<INITIAL>
"if" { return IF; }
"input" { return INPUT; }
"output" { return OUTPUT; }

"int" { return INT; }
"float" { return FLOAT; }

"cast<<int>>" { 
  yylval.idData.type = TYPE_INT;
  return CAST; }

"cast<<float>>" { 
  yylval.idData.type = TYPE_FLOAT;
  return CAST; }

[+-] { yylval.idData.value.sval = strdup(yytext); return ADDOP; }
[*/] { yylval.idData.value.sval = strdup(yytext); return MULOP; }

{PUNCTUATIONS} { return yytext[0]; }

{DIGIT}+ { yylval.idData.type = TYPE_INT; yylval.idData.value.ival = atoi(yytext); return NUM; }
{DIGIT}+"."{DIGIT}* 	{ yylval.idData.type = TYPE_FLOAT; yylval.idData.value.fval = atof(yytext); return NUM; }
({LETTER}|_)({LETTER}|{DIGIT}|_)*	{ yylval.idData.type = TYPE_ID; yylval.idData.value.sval = strdup(yytext); return ID; }

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