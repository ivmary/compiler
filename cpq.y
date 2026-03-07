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
    
    typedef struct idData {
        SymbolType type;
        union {
            int ival;
            float fval;
        } value;
    } NumData;

    typedef struct idNamesList {
        char* name;
        struct idNamesList *next;
    } idNamesList;
}

%union {
    Symbol *sym;
    char *sval;
    int ival;
    float fval;
    NumData num;
    idNamesList *namesList;
    idData idData;
}

%token <sval> ID
%token <num> NUM
%token INT FLOAT 
%token RELOP ADDOP MULOP
%token IF ELSE SWITCH CASE BREAK DEFAULT WHILE OUTPUT INPUT 
%token <idData> CAST
%token NOT OR AND

/* %type <ival> stmt_block */
/* %type <ival> declarations type  */
%type declarations
%type <sym> factor
%type <idData> program term expression type
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
    idNamesList *tempId = $1;

    while(tempId){ // Insert all declared variables with default value
        if($3.type == TYPE_INT) {
            Symbol * temp=insertInt(tempId->name,314);
            }
        else if($3.type == TYPE_FLOAT) {
            Symbol * temp=insertFloat(tempId->name, 3.14);
            }
        else {// TODO
            Symbol * temp=insertPtr(tempId->name, NULL);
            } 
        tempId = tempId-> next;
    }

    tempId = $1;
    while(tempId){ // Free the temporary declaration names list
        idNamesList *toRelease = tempId;
        tempId = tempId->next;
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
    SymbolType idType = $1.type;
    
    if(idType == TYPE_ID) {
        Symbol *id = lookup($1.value.sval);

        if(id && id->type == $3.type){ // Checking if the vaeiable exists and if we try to assign the correct type
            if(id->type == TYPE_INT) {
                printf("IASN %s %d\n",id->name,$3.value.ival);
            } else if(id->type == TYPE_FLOAT) {
                printf("RASN %s %f\n",id->name,$3.value.fval);
            } else {
                printf("error\n"); // Trying to assing unsupported type
            }
        } else {
            printf("error\n");
        }
    } else {
        printf("error\n");
    }
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

if_stmt : IF '(' boolexpr ')' stmt ELSE stmt {

}

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
| term {
    
}

term : term MULOP factor { 
    if (($1.type == TYPE_INT || $1.type == TYPE_FLOAT) && 
        ($3.type == TYPE_INT || $3.type == TYPE_FLOAT)) {
        if ($1.type == TYPE_FLOAT || $3.type == TYPE_FLOAT) {
            float first  = ($1.type == TYPE_FLOAT) ? $1.value.fval : (float)$1.value.ival;
            float second = ($3.type == TYPE_FLOAT) ? $3.value.fval : (float)$3.value.ival;

            Symbol *temp = createTempFloat(first*second);
            $$.type = TYPE_FLOAT;
            $$.value.fval = first * second;
            printf("RADD %s\n",temp->name);
        } else {
            printf("IADD \n");
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
        $$. value.fval = $2.value.fval;
    }
}
| CAST '(' expression ')' { 
    if ($3.type != TYPE_INT && $3.type != TYPE_FLOAT) {
        $$.type = -1;   /* type error */
    }
    else if ($1.type == TYPE_INT) { // Cast to INT
        $$.type = TYPE_INT;

        if ($3.type == TYPE_INT)
            $$.value.ival = $3.value.ival;
        else
            $$.value.ival = (int)$3.value.fval;
        printf("RTOI \n");
    }
    else { /* Cast to FLOAT */
        $$.type = TYPE_FLOAT;

        if ($3.type == TYPE_INT)
            $$.value.fval = (float)$3.value.ival;
        else
            $$.value.fval = $3.value.fval;
        printf("ITOR \n");
    }
  }
| ID { 
    Symbol *id = lookup($1);
    if(id) {
        $$ = id;
    }
    else {
        printf("undeclared identifier\n"); // TODO: error
        $$ = NULL;
    }
    free($1);
}
| NUM { 
    $$.type = $1.type;
    if($1.type == TYPE_INT) {
        $$.value.ival = $1.value.ival; }
    else if($1.type == TYPE_FLOAT) {
        $$.value.fval = $1.value.fval;
    }
}

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

