%code {
    #include <stdio.h>
    #include <string.h>

    extern int yylex();
    extern int yyparse();
    extern FILE* yyin;
    void yyerror (const char *s);

    

}

%code requires {
    #include "symbol_table.h"
    
    typedef struct data {
        SymbolType type;
        union {
            int ival;
            float fval;
            char* sval;
        } value;
    } data;

    typedef struct idNamesList {
        char* name;
        struct idNamesList *next;
    } idNamesList;
}

%union {
    idNamesList *namesList;
    data data;
}

%token <data> INT FLOAT ID NUM
%token RELOP ADDOP MULOP
%token IF ELSE SWITCH CASE BREAK DEFAULT WHILE OUTPUT INPUT 
%token <data> CAST
%token NOT OR AND

/* %type <ival> stmt_block */
/* %type <ival> declarations type  */
%type declarations
%type <data> program term factor expression declaration type stmt_block
%type <namesList> idlist

%define parse.error verbose

%start program

%locations
%%

program: declarations stmt_block { 
    printf("HALT\n"); // End of program
  }

declarations : declarations declaration { } 
| /* epsilon */ {}

declaration : idlist ':' type ';' { // Not outputing anything
    idNamesList *temp = $1;

    while(temp){ // Insert all declared variables with default value
        if($3.type == TYPE_INT) insertInt(TYPE_INT,temp->name,314);
        else if($3.type == TYPE_FLOAT) insertFloat(TYPE_FLOAT, temp->name, 3.14);
        else insertPtr(TYPE_ID, temp->name, NULL); // TODO
        temp = temp-> next;
    }

    temp = $1;
    while(temp){ // Free the temporary declaration names list
        idNamesList *toRelease = temp;
        temp = temp->next;
        free(toRelease);
    }
}

type : INT { $$.type = TYPE_INT; } 
| FLOAT { $$.type = TYPE_FLOAT; }

idlist : idlist ',' ID {
    idNamesList *temp = malloc(sizeof(idNamesList));
    temp->name = strdup($3.value.sval);
    temp->next = $1;
    $$ = temp;
}| ID {
    idNamesList *temp = malloc(sizeof(idNamesList));
    temp->name = strdup($1.value.sval);
    $$=temp;
}

stmt : assignment_stmt {

}
| input_stmt {

}
| output_stmt
| if_stmt
| while_stmt
| switch_stmt
| break_stmt
| stmt_block

assignment_stmt : ID '=' expression ';' {
    printf("temp");
}

input_stmt : INPUT '(' ID ')' ';' {
    SymbolType idType = $3.type;
    
    if(idType == TYPE_ID) {
        Symbol *id = lookup($3.value.sval);
        
        if(id){
            if(id->type == TYPE_INT) {
                printf("IINP %s\n",id->name);
            } else if(id->type == TYPE_FLOAT){
                printf("RINP %s\n",id->name);
            }
        } else {
            printf("Vaeiable %s is not declared\n",$3.value.sval);
        }
    }
    else {
        printf("error!\n");
    }
}

output_stmt : OUTPUT '(' expression ')' ';' {
    SymbolType idType = $3.type;
    
    if(idType == TYPE_ID) {
        Symbol *id = lookup($3.value.sval);
        
        if(id){
            if(id->type == TYPE_INT) {
                printf("IPRT %s\n",id->name);
            } else if(id->type == TYPE_FLOAT){
                printf("RPRT %s\n",id->name);
            }
        } else {
            printf("Vaeiable %s is not declared\n",$3.value.sval);
        }
    }
    else {
        printf("error!\n");
    }
}

if_stmt : IF '(' boolexpr ')' stmt ELSE stmt

while_stmt : WHILE '(' boolexpr ')' stmt

switch_stmt : SWITCH '(' expression ')' '{' caselist DEFAULT ':' stmtlist '}'

caselist : caselist CASE NUM ':' stmtlist 
| /* epsilon */

break_stmt : BREAK ';'

stmt_block : '{' stmtlist '}'

stmtlist : stmtlist stmt 
| /*epsilon */

boolexpr : boolexpr OR boolterm
| boolterm

boolterm : boolterm AND boolfactor 
| boolfactor

boolfactor : NOT '(' boolexpr ')'
| expression RELOP expression


expression : expression ADDOP term { 
    if (($1.type == TYPE_INT || $1.type == TYPE_FLOAT) && 
        ($3.type == TYPE_INT || $3.type == TYPE_FLOAT)) {
        if ($1.type == TYPE_FLOAT || $3.type == TYPE_FLOAT) {
            $$.type = TYPE_FLOAT;

            float first  = ($1.type == TYPE_FLOAT) ? $1.value.fval : $1.value.ival;
            float second = ($3.type == TYPE_FLOAT) ? $3.value.fval : $3.value.ival;

            $$.value.fval = first + second;
        } else {
            $$.type = TYPE_INT;
            $$.value.ival = $1.value.ival + $3.value.ival;
        }
    } else {
        fprintf(stderr, "Type error: incompatible types for addition\n");
        $$.type = -1; // Indicate an error
    }
  }
| term

term : term MULOP factor { 
    if (($1.type == TYPE_INT || $1.type == TYPE_FLOAT) && 
        ($3.type == TYPE_INT || $3.type == TYPE_FLOAT)) {
        if ($1.type == TYPE_FLOAT || $3.type == TYPE_FLOAT) {
            $$.type = TYPE_FLOAT;

            float first  = ($1.type == TYPE_FLOAT) ? $1.value.fval : (float)$1.value.ival;
            float second = ($3.type == TYPE_FLOAT) ? $3.value.fval : (float)$3.value.ival;

            $$.value.fval = first * second;
        } else {
            $$.type = TYPE_INT;
            $$.value.ival = $1.value.ival * $3.value.ival;
        }
    } else {
        fprintf(stderr, "Type error: incompatible types for addition\n");
        $$.type = -1; // Indicate an error
    }
  }
| factor

factor : '(' expression ')' {
    if ($2.type == TYPE_INT) {
            $$.type = TYPE_INT;
            $$.value.ival = $2.value.ival;
    } else if ($2.type == TYPE_FLOAT) {
        $$.type = TYPE_FLOAT;
        $$.value.fval = $2.value.fval;
    }
}
| CAST '(' expression ')' { 
    if ($3.type != TYPE_INT && $3.type != TYPE_FLOAT) {
        $$.type = -1;   /* type error */
    }
    else if ($1.type == TYPE_INT) {
        $$.type = TYPE_INT;

        if ($3.type == TYPE_INT)
            $$.value.ival = $3.value.ival;
        else
            $$.value.ival = (int)$3.value.fval;
    }
    else { /* TYPE_FLOAT */
        $$.type = TYPE_FLOAT;

        if ($3.type == TYPE_INT)
            $$.value.fval = (float)$3.value.ival;
        else
            $$.value.fval = $3.value.fval;
    }
  }
| ID { 
    $$.type = $1.type; }
| INT { 
    $$ = $1;
    printf("NUM: %d\n", $1.value.ival); }
| FLOAT { 
    $$ = $1;
    printf("NUM: %f\n", $1.value.fval); }

%%

int main(int argc, char **argv){
    extern FILE *yyin;
    initSymbolTable();

    if (argc != 2) {
        fprintf (stderr, "Usage: %s <input-file-name>\n", argv[0]);
	    return 1;
    }
    yyin = fopen (argv [1], "r");
    if (yyin == NULL) {
        fprintf (stderr, "failed to open %s\n", argv[1]);
        return 2;
    }
    
    yyparse ();
    
    fclose (yyin);
    cleanSymbolTable();
    return 0;
}


void yyerror (const char *s)
{
  extern int yylineno;
  fprintf (stderr, "line %d: %s\n", yylineno, s);
}

