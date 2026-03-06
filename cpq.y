%code {
    #include <stdio.h>

    extern int yylex();
    extern int yyparse();
    extern FILE* yyin;
    void yyerror (const char *s);

}

%code requires {

}

%union {
    int type;
    int ival;
    float fval;
    char* sval;
}

%token<ival> INT
%token<fval> FLOAT
%token ID
%token NUM
%token STRING
%token RELOP
%token ADDOP
%token MULOP
%token CAST
%token TYPE
%token NOT
%token OR
%token AND
%token IF
%token ELSE
%token SWITCH
%token CASE
%token BREAK
%token DEFAULT
%token WHILE
%token OUTPUT
%token INPUT

%type <ival> stmt_block
%type <ival> declarations
%type <ival> type

%define parse.error verbose

%start program
%%

program: term
term : term MULOP factor
| factor
factor :    ID
| NUM

%%

int main(int argc, char **argv){
    yyin = stdin;

	do {
		yyparse();
	} while(!feof(yyin));

	return 0;
}

void yyerror (const char *s)
{
  extern int line;
  printf("hi");
  
  //fprintf (stderr, "line %d: %s\n", line, s);
}