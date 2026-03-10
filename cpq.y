%code {
    #include <stdio.h>
    #include <stdarg.h>
    #include <string.h>
    #include <stdlib.h>
    
    extern int yylex();
    extern int yyparse();
    extern FILE* yyin;
    void yyerror (const char *s);
    static const char *relop_to_opcode(RelOp op);
    void emit(char *fmt,...);
}

%code requires {
    #include "symbol_table.h"
    #define MAX_INSTR 1000
    #define INSTR_LEN 64
    
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

    typedef enum {
        RELOP_EQ, // == 
        RELOP_NE, // !=
        RELOP_LT, // <
        RELOP_GT, // >
        RELOP_LE, // <=
        RELOP_GE // >=
    } RelOp;

    extern char *instructions[MAX_INSTR];
    extern int next_instr;
}

%union {
    Symbol *sym;
    char *sval;
    int ival;
    float fval;
    NumData num;
    idNamesList *namesList;
    char op;
    RelOp relop;
    SymbolType type;
}

%token <sval> ID
%token <num> NUM
%token INT FLOAT 
%token <relop> RELOP 
%token <op> ADDOP MULOP
%token IF ELSE SWITCH CASE BREAK DEFAULT WHILE OUTPUT INPUT 
%token <type> CAST
%token NOT OR AND

%type declarations
%type <sym> factor term expression boolfactor boolterm boolexpr if_stmt
%type <type> type
%type program 
%type <namesList> idlist

%define parse.error verbose

%start program

%locations
%%

program: {
    for(int i=0;i<MAX_INSTR;i++) instructions[i] = NULL;
} declarations stmt_block { 
    for(int i=0;i<next_instr;i++){
        printf("%s\n",instructions[i]);
        free(instructions[i]);
    }
    printf("%d:HALT\n",next_instr); // End of program
  }

declarations : declarations declaration { } 
| /* epsilon */ {}

declaration : idlist ':' type ';' {
    idNamesList *tempId = $1;

    while(tempId){ // Insert all declared variables with default value
        if($3 == TYPE_INT) {
            Symbol * temp=insertInt(tempId->name,314);
            }
        else if($3 == TYPE_FLOAT) {
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
}}

type : INT { $$ = TYPE_INT; } 
| FLOAT { $$ = TYPE_FLOAT; }

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
            emit("%d:IASN %s %s",next_instr,id->name,$3->name);
        } else if(id->type == TYPE_FLOAT) {
            emit("%d:RASN %s %s",next_instr,id->name,$3->name);
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
            emit("%d:IINP %s",next_instr,id->name);
        } else if(id->type == TYPE_FLOAT){
            emit("%d:RINP %s",next_instr,id->name);
        }
    }
    else {
        printf("error!\n");
    }
}

output_stmt : OUTPUT '(' expression ')' ';' {
    if($3){
        if($3->type == TYPE_INT) {
            emit("%d:IPRT %s",next_instr,$3->name);
        } else if($3->type == TYPE_FLOAT){
            emit("%d:RPRT %s",next_instr,$3->name);
        }
    } else {
        printf("Vaeiable %s is not declared\n",$3->name);
    }
}

if_stmt : IF '(' boolexpr ')' {
        emit("%d:JMPZ ? %s",next_instr,$3->name);
    }  stmt { emit("%d:JMP ? ",next_instr); } ELSE stmt {
    $$ = NULL;
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
{
    $$ = NULL;
}
| boolterm

boolterm : boolterm AND boolfactor 
| boolfactor

boolfactor : NOT '(' boolexpr ')' {

}
| expression RELOP expression {
    if(!$1 || !$3) { $$=NULL; }
    else if(!($1->type == TYPE_INT || $1->type == TYPE_FLOAT) && 
        ($3->type == TYPE_INT || $3->type == TYPE_FLOAT)) { $$=NULL; }
    else {
        int useFloat = ($1->type == TYPE_FLOAT || $3->type == TYPE_FLOAT);

        Symbol *first  = useFloat ? convertToFloat($1) : $1;
        Symbol *second = useFloat ? convertToFloat($3) : $3;
        if($1->type == TYPE_INT) {emit("%d:ITOR %s %s",next_instr, first->name, $1->name);}
        if($3->type==TYPE_INT) {emit("%d:ITOR %s %s",next_instr, second->name, $3->name);}

        if (!first || !second) {
            $$ = NULL;
        } else {
            const char *mn = relop_to_opcode($2);
            if (!mn) {
                $$ = NULL;
            } else {
                Symbol *result = createTemp(TYPE_INT, (SymbolValue){0});
                emit("%d:%c%s %s %s %s",
                    next_instr,
                    useFloat ? 'R' : 'I',
                    mn,
                    result->name,
                    first->name,
                    second->name);
                $$ = result;
            }
        }
        
    }
}

expression : expression ADDOP term { 
    if (($1->type == TYPE_INT || $1->type == TYPE_FLOAT) && 
        ($3->type == TYPE_INT || $3->type == TYPE_FLOAT)) {

        SymbolType resType = ($1->type == TYPE_FLOAT || $3->type == TYPE_FLOAT) ? TYPE_FLOAT : TYPE_INT;
        SymbolValue dummy = (SymbolValue){0};
        Symbol *res = createTemp(resType, dummy);

        if (resType == TYPE_FLOAT) {      
            Symbol *first = convertToFloat($1);      
            Symbol *second = convertToFloat($3);
            if($1->type == TYPE_INT) {emit("%d:ITOR %s %s",next_instr, first->name, $1->name);}
            if($3->type==TYPE_INT) {emit("%d:ITOR %s %s",next_instr, second->name, $3->name);}
   
            if (!first || !second) {
                $$ = NULL;
            } else if($2 == '+') {
                emit("%d:RADD %s %s %s",next_instr,res->name,first->name,second->name);
            } else if($2 == '-'){
                emit("%d:RSUB %s %s %s",next_instr,res->name,first->name,second->name);
            }
        } else { 
            if($2 == '+') {
                emit("%d:IADD %s %s %s",next_instr,res->name,$1->name,$3->name);
            } else if($2 == '-'){
                emit("%d:ISUB %s %s %s",next_instr,res->name,$1->name,$3->name);
            }    
        }
        $$ = res;
    } else {
        fprintf(stderr, "Type error: incompatible types for term\n");
        $$ = NULL;
    }}
| term {
    $$ = $1;
}

term : term MULOP factor { 
    if (($1->type == TYPE_INT || $1->type == TYPE_FLOAT) && 
        ($3->type == TYPE_INT || $3->type == TYPE_FLOAT)) {

        SymbolType resType = ($1->type == TYPE_FLOAT || $3->type == TYPE_FLOAT) ? TYPE_FLOAT : TYPE_INT;
        SymbolValue dummy = (SymbolValue){0};
        Symbol *res = createTemp(resType, dummy);

        if (resType == TYPE_FLOAT) { 
            Symbol *first = convertToFloat($1);      
            Symbol *second = convertToFloat($3);
            if($1->type == TYPE_INT) {emit("%d:ITOR %s %s",next_instr, first->name, $1->name);}
            if($3->type==TYPE_INT) {emit("%d:ITOR %s %s",next_instr, second->name, $3->name);}

            if (!first || !second) {
                $$ = NULL;
            } else if($2 == '*') {
                emit("%d:RMLT %s %s %s",next_instr,res->name,first->name,second->name);
            } else if($2 == '/'){
                emit("%d:RDIV %s %s %s",next_instr,res->name,first->name,second->name);
            }
        } else { 
            if($2 == '*') {
                emit("%d:IMLT %s %s %s",next_instr,res->name,$1->name,$3->name);
            } else if($2 == '/'){
                emit("%d:IDIV %s %s %s",next_instr,res->name,$1->name,$3->name);
            }    
        }
        $$ = res;
    } else {
        fprintf(stderr, "Type error: incompatible types for term\n");
        $$ = NULL;
    }}
| factor {
    $$ = $1;
}

factor : '(' expression ')' {
    $$ = $2;}
| CAST '(' expression ')' { 
    if ($3->type != TYPE_INT && $3->type != TYPE_FLOAT) {
        $$ = NULL;   /* type error */
    }
    else{
        Symbol *res = NULL;

        if ($1 == TYPE_INT) { // Cast to INT
            res = createTemp(TYPE_INT,$3->value);

            emit("%d:RTOI %s %s",next_instr,res->name,$3->name);
        }
        else { /* Cast to FLOAT */
            res = createTemp(TYPE_FLOAT,$3->value);

            emit("%d:ITOR %s %s",next_instr,res->name,$3->name);
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
    
    addIRSym(num);
    $$ = num; }

%%

char *instructions[MAX_INSTR];
int next_instr = 0;

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
    freeTemporaries();

    return 0;
}


void yyerror (const char *s)
{
  extern int yylineno;
  fprintf (stderr, "line %d: %s\n", yylineno, s);
}

static const char *relop_to_opcode(RelOp op) {
    switch (op) {
        case RELOP_EQ: return "EQL";
        case RELOP_NE: return "NQL";
        case RELOP_LT: return "LSS";
        case RELOP_GT: return "GRT";
        /* case RELOP_LE: return "LEQ";
        case RELOP_GE: return "GEQ"; */
        default:       return NULL;
    }
}

void emit(char *fmt, ...){
    if(next_instr >= MAX_INSTR){
        fprintf(stderr,"Instruction buffer overflow\n");
        exit(1);
    }

    char buffer[INSTR_LEN];

    va_list args;
    va_start(args, fmt);
    vsnprintf(buffer, sizeof(buffer), fmt, args);
    va_end(args);

    instructions[next_instr] = strdup(buffer);
    next_instr++;
}