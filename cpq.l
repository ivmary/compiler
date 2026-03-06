%{

  #include "cpq.tab.h"

#include <string.h> 
#include <stdlib.h>

// extern int atoi (const char *);
%}

%option noyywrap

%option yylineno

/* exclusive start conditions -- deal with two types of comments */ 
%x COMMENT
%x STAR_COMMENT

%%
<INITIAL>[0-9]+   { yylval.ival = atoi(yytext); return NUM; }

[a-zA-Z][a-zA-Z0-9]*       {  return ID; }

\"([^\\"\n]|\\\")*\" {  return STRING; }

[(){}[\]] { return yytext[0]; }

[\t\r ]+  { /* skip white space */ }

[\n]+       {  }
                                         			 
"//"       { BEGIN (COMMENT); }

<COMMENT>.+ { /* skip comment */ }
<COMMENT>\n {  /* end of comment --> resume normal processing */
                BEGIN (0); }

 /*  note: the flex manual contains slightly better code for handling
   comments. see the section on start conditions */  				
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

// int main (int argc, char **argv)
// {
//    extern FILE *yyin;
//    int token;

//    if (argc != 2) {
//       fprintf(stderr, "Usage: %s <input file name>\n", argv [0]);
//       exit (1);
//    }

//    yyin = fopen (argv[1], "r");

//    while ((token = yylex ()) != 0)
//      switch (token) {
// 	    case NUM: printf("NUMBER : %d\n", yylval.ival);
// 	              break;
//         case ID:     printf ("ID ");
// 	              break;
// 	    case STRING: printf ("STRING");
// 	              break;
//          default:     fprintf (stderr, "error ... \n"); exit (1);
//      } 
//    fclose (yyin);
//    exit (0);
// }

