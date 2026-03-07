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
    
    typedef struct NumData {
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
    char op;
    SymbolType type;
}

%token <sval> ID
%token <num> NUM
%token INT FLOAT 
%token RELOP 
%token <op> ADDOP MULOP
%token IF ELSE SWITCH CASE BREAK DEFAULT WHILE OUTPUT INPUT 
%token <type> CAST
%token NOT OR AND

/* %type <ival> stmt_block */
/* %type <ival> declarations type  */
%type declarations
%type <sym> factor term expression type
%type program   
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
        if($3->type == TYPE_INT) {
            Symbol * temp=insertInt(tempId->name,314);
            }
        else if($3->type == TYPE_FLOAT) {
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

type : INT { $$->type = TYPE_INT; } 
| FLOAT { $$->type = TYPE_FLOAT; }

idlist : idlist ',' ID {
    idNamesList *temp = malloc(sizeof(idNamesList));
    temp->name = strdup($3);
    temp->next = $1;
    $$ = temp;
}| ID {
    idNamesList *temp = malloc(sizeof(idNamesList));
    temp->name = strdup($1);
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
    Symbol *id = lookup($1);

    if(id && id->type == $3->type){
        if(id->type == TYPE_INT) {
            printf("IASN %s %s\n",id->name,$3->name);
        } else if(id->type == TYPE_FLOAT) {
            printf("RASN %s %s\n",id->name,$3->name);
        } else {
            printf("error\n"); // Trying to assing unsupported type
        }
    } else {
        printf("error\n");
    }
}

input_stmt : INPUT '(' ID ')' ';' {
    Symbol *id = lookup($3);
    if(id) {
        if(id->type == TYPE_INT) {
            printf("IINP %s\n",id->name);
        } else if(id->type == TYPE_FLOAT){
            printf("RINP %s\n",id->name);
        }
    }
    else {
        printf("error!\n");
    }
}

output_stmt : OUTPUT '(' expression ')' ';' {
    SymbolType idType = $3->type;
    
    if(idType == TYPE_ID) {
        Symbol *id = lookup($3->name);
        
        if(id){
            if(id->type == TYPE_INT) {
                printf("IPRT %s\n",id->name);
            } else if(id->type == TYPE_FLOAT){
                printf("RPRT %s\n",id->name);
            }
        } else {
            printf("Vaeiable %s is not declared\n",$3->name);
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
    if (($1->type == TYPE_INT || $1->type == TYPE_FLOAT) && 
        ($3->type == TYPE_INT || $3->type == TYPE_FLOAT)) {

        SymbolType resType = ($1->type == TYPE_FLOAT || $3->type == TYPE_FLOAT) ? TYPE_FLOAT : TYPE_INT;
        SymbolValue dummy = (SymbolValue){0};
        Symbol *res = createTemp(resType, dummy);

        if (resType == TYPE_FLOAT) {            
            if($2 == '+') {
                printf("RADD %s %s %s\n",res->name,$1->name,$3->name);
            } else if($2 == '-'){
                printf("RSUB %s %s %s\n",res->name,$1->name,$3->name);
            }
        } else { 
            if($2 == '+') {
                printf("IADD %s %s %s\n",res->name,$1->name,$3->name);
            } else if($2 == '-'){
                printf("ISUB %s %s %s\n",res->name,$1->name,$3->name);
            }    
        }
        $$ = res;
    } else {
        fprintf(stderr, "Type error: incompatible types for term\n");
        $$ = NULL;
    }}
| term {
    
}

term : term MULOP factor { 
    if (($1->type == TYPE_INT || $1->type == TYPE_FLOAT) && 
        ($3->type == TYPE_INT || $3->type == TYPE_FLOAT)) {

        SymbolType resType = ($1->type == TYPE_FLOAT || $3->type == TYPE_FLOAT) ? TYPE_FLOAT : TYPE_INT;
        SymbolValue dummy = (SymbolValue){0};
        Symbol *res = createTemp(resType, dummy);

        if (resType == TYPE_FLOAT) {            
            if($2 == '*') {
                printf("RMLT %s %s %s\n",res->name,$1->name,$3->name);
            } else if($2 == '/'){
                printf("RDIV %s %s %s\n",res->name,$1->name,$3->name);
            }
        } else { 
            if($2 == '*') {
                printf("IMLT %s %s %s\n",res->name,$1->name,$3->name);
            } else if($2 == '/'){
                printf("IDIV %s %s %s\n",res->name,$1->name,$3->name);
            }    
        }
        $$ = res;
    } else {
        fprintf(stderr, "Type error: incompatible types for term\n");
        $$ = NULL;
    }}
| factor

factor : '(' expression ')' {
    $$ = $2;
}
| CAST '(' expression ')' { 
    if ($3->type != TYPE_INT && $3->type != TYPE_FLOAT) {
        $$ = NULL;   /* type error */
    }
    else{
        Symbol *res = NULL;

        if ($1 == TYPE_INT) { // Cast to INT
            res = createTemp(TYPE_INT,$3->value);
            
            printf("RTOI %s %s\n",res->name,$3->name);
        }
        else { /* Cast to FLOAT */
            res = createTemp(TYPE_FLOAT,$3->value);

            printf("ITOR %s %s\n",res->name,$3->name);
        }

        $$ = res;
    }}
| ID { 
    Symbol *id = lookup($1);
    if(id) {
        $$ = id;
    }
    else {
        printf("undeclared identifier\n"); // TODO: error
        $$ = NULL;
    }
    free($1); }
| NUM { 
    Symbol *num = malloc(sizeof(Symbol));

    num->type = $1.type;
    num->next = NULL;

    if (num->type == TYPE_INT) {
        num->value.i = $1.value.ival;

        char buf[32];
        snprintf(buf, sizeof(buf), "%d", num->value.i);
        num->name = strdup(buf);
    } else { /* TYPE_FLOAT */
        num->value.f = $1.value.fval;

        char buf[64];
        snprintf(buf, sizeof(buf), "%g", num->value.f);
        num->name = strdup(buf);
    }

    $$ = num; }

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

