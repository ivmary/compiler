%code {
    #include <stdio.h>
    // #include <stdarg.h>
    #include <string.h>
    // #include <stdlib.h>
    
    extern int yylex();
    extern int yyparse();
    extern FILE* yyin;
    void yyerror (const char *s);
    static const char *relop_to_opcode(RelOp op);
    void emit(const char *op,const char *arg1,const char *arg2,const char *arg3);
    jmpList *makeList(int instr);
    jmpList *merge(jmpList *first, jmpList *second);
    void patch_instruction(int instr_ptr, int target);
    void backpatch(jmpList *lst, int target);
    void printCode();
    void freeCode();
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

    typedef struct jmpList{
        int ptr;
        struct jmpList *next;
    } jmpList;

    typedef struct {
        jmpList* truelist;
        jmpList* falselist;
    } BoolAttr;

    typedef struct {
        jmpList* breaklist;
    } StmtAttr;

    typedef struct {
        Symbol* expr;
        jmpList* breaklist;
        jmpList* nextlist;
    } CaseAttr;

    typedef struct Instruction{
        const char* op;     // instruction name
        char* arg1;   // destination or label
        char* arg2;
        char* arg3;
    }Instruction;

    extern Instruction code[MAX_INSTR];
    extern int next_instr;
}

%union {
    Symbol *sym;
    char *sval;
    int ival;
    //float fval;
    NumData num;
    idNamesList *namesList;
    char op;
    RelOp relop;
    SymbolType type;
    BoolAttr *boolAttr;
    StmtAttr *stmtAttr;
    CaseAttr *caseAttr;
    jmpList *next;
    int marker;
}

%token <sval> ID
%token <num> NUM
%token INT FLOAT 
%token <relop> RELOP 
%token <op> ADDOP MULOP
%token IF ELSE SWITCH CASE BREAK DEFAULT WHILE OUTPUT INPUT 
%token <type> CAST
%token NOT OR AND

%type <sym> factor term expression S
%type <boolAttr> boolfactor boolterm boolexpr 
%type <stmtAttr> break_stmt stmt_block stmtlist stmt if_stmt while_stmt switch_stmt 
%type <caseAttr> caselist
%type <type> type
/* %type program declarations */
%type <namesList> idlist
%type <marker> M
%type <next> N

%define parse.error verbose

%start program

%locations
%%

program: declarations stmt_block { 
    printCode();
    printf("%d: HALT\n",next_instr); // End of program
    freeCode();
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
    $$ = malloc(sizeof(StmtAttr));
    $$->breaklist = NULL;
}
| input_stmt {
    $$ = malloc(sizeof(StmtAttr));
    $$->breaklist = NULL;
}
| output_stmt {
    $$ = malloc(sizeof(StmtAttr));
    $$->breaklist = NULL;
}
| if_stmt { 
    $$ = $1;
}
| while_stmt { 
    $$ = $1;
}
| switch_stmt { 
    $$ = $1;
}
| break_stmt { 
    $$ = $1;
}
| stmt_block { 
    $$ = $1;
}

assignment_stmt : ID '=' expression ';' {
    Symbol *id = lookup($1);

    if(id && id->type == $3->type){
        if(id->type == TYPE_INT) {
            emit("IASN",id->name,$3->name,NULL);
        } else if(id->type == TYPE_FLOAT) {
            emit("RASN",id->name,$3->name,NULL);
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
            emit("IINP",id->name,NULL,NULL);
        } else if(id->type == TYPE_FLOAT){
            emit("RINP",id->name,NULL,NULL);
        }
    }
    else {
        printf("error!\n");
    }
}

output_stmt : OUTPUT '(' expression ')' ';' {
    if($3){
        if($3->type == TYPE_INT) {
            emit("IPRT",$3->name,NULL,NULL);
        } else if($3->type == TYPE_FLOAT){
            emit("RPRT",$3->name,NULL,NULL);
        }
    } else {
        printf("Vaeiable %s is not declared\n",$3->name);
    }
}

if_stmt : IF '(' boolexpr ')' M {
    backpatch($3->truelist,$5);
}
stmt N ELSE M {
    backpatch($3->falselist,$10);
}
stmt {
    backpatch($8,next_instr);
    $$ = malloc(sizeof(StmtAttr));
    $$->breaklist = merge($7->breaklist,$12->breaklist);
}

while_stmt : WHILE '(' M boolexpr ')' M stmt {
    char buff[16];
    snprintf(buff,sizeof(buff),"%d",$3);
    emit("JUMP",buff,NULL,NULL);

    backpatch($4->truelist, $6);
    backpatch($4->falselist,next_instr);
    backpatch($7->breaklist,next_instr);
    $$ = malloc(sizeof(StmtAttr));
    $$->breaklist = NULL;
}

switch_stmt : SWITCH '(' expression ')' S '{' caselist M DEFAULT ':' stmtlist '}' {
    if($3->type!=TYPE_INT) printf("Type error: switch expression must be int\n");
    else {
    }
    backpatch($7->breaklist,next_instr);
    backpatch($7->nextlist, $8);
    backpatch($11->breaklist,next_instr);

    $$ = malloc(sizeof(StmtAttr));
    $$->breaklist = NULL;
}

S: /* empty */ {
    $$ = $<sym>-2;
}

caselist : caselist CASE NUM ':' {
    backpatch($1->nextlist, next_instr);
    if($3.type != TYPE_INT) printf("Type error: switch expression must be int\n");
    
    char buff[16];

    snprintf(buff,sizeof(buff),"%d",$3.value.ival);

    Symbol *temp = createTemp(TYPE_INT,(SymbolValue){0});
    emit("IEQL",temp->name,$1->expr->name,buff);

    $<ival>$ = next_instr;
    emit("JMPZ","_",temp->name,NULL);

}  stmtlist {
    $$ = malloc(sizeof(CaseAttr));
    $$->expr = $1->expr;    
    $$->breaklist = merge($1->breaklist,$6->breaklist);
    $$->nextlist = makeList($<ival>5);

}
| /* epsilon */ {
    $$ = malloc(sizeof(CaseAttr));
    $$->expr = $<sym>-3;
    $$->breaklist = NULL;
    $$->nextlist = NULL;
}

break_stmt : BREAK ';' {
    $$ = malloc(sizeof(StmtAttr));
    $$->breaklist = makeList(next_instr);
    emit("JUMP","_",NULL,NULL);
}

stmt_block : '{' stmtlist '}' {
    $$ = $2;
}

stmtlist : stmtlist stmt {
    $$ = malloc(sizeof(StmtAttr));
    $$->breaklist = merge($1->breaklist, $2->breaklist);
}
| /* epsilon */ { 
    $$ = malloc(sizeof(StmtAttr));
    $$->breaklist = NULL; 
}

boolexpr : boolexpr OR M {
    backpatch($1->falselist, $3);
}
boolterm {
    $$ = malloc(sizeof(BoolAttr));
    $$->truelist = merge($1->truelist,$5->truelist);
    $$->falselist = $5->falselist;
}
| boolterm {
    $$ = $1;
}

boolterm : boolterm AND M {
    backpatch($1->truelist, $3);
}
boolfactor {
    $$ = malloc(sizeof(BoolAttr));
    $$->falselist = merge($1->falselist,$5->falselist);
    $$->truelist = $5->truelist;
}
| boolfactor {
    $$=$1;
}

boolfactor : NOT '(' boolexpr ')' {
    $$ = $3;

    jmpList* tmp = $$->truelist;
    $$->truelist = $$->falselist;
    $$->falselist = tmp;
}
| expression RELOP expression {
    if(!$1 || !$3) { $$=NULL; }
    else if(!($1->type == TYPE_INT || $1->type == TYPE_FLOAT) && 
        !($3->type == TYPE_INT || $3->type == TYPE_FLOAT)) { $$=NULL; }
    else {
        int useFloat = ($1->type == TYPE_FLOAT || $3->type == TYPE_FLOAT);

        Symbol *first = $1;
        Symbol *second = $3;

        if(useFloat){
            if($1->type == TYPE_INT){
                first = convertToFloat($1);
                emit("ITOR", first->name, $1->name, NULL);
            }

            if($3->type == TYPE_INT){
                second = convertToFloat($3);
                emit("ITOR", second->name, $3->name, NULL);
            }
        }

        if (!first || !second) {
            $$ = NULL;
        } else {
            $$ = malloc(sizeof(BoolAttr));

            Symbol *temp = createTemp(TYPE_INT,(SymbolValue){0});

            char opcode[10];
            sprintf(opcode, "%c%s", useFloat ? 'R' : 'I', relop_to_opcode($2));
            emit(opcode,
                temp->name,
                first->name,
                second->name);
            $$->falselist = makeList(next_instr);
            emit("JMPZ","_",temp->name,NULL);

            $$->truelist = makeList(next_instr);
            emit("JUMP","_",NULL,NULL);
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
            Symbol *first = $1;
            Symbol *second = $3;

            if($1->type == TYPE_INT){
                first = convertToFloat($1);
                emit("ITOR", first->name, $1->name, NULL);
            }

            if($3->type == TYPE_INT){
                second = convertToFloat($3);
                emit("ITOR", second->name, $3->name, NULL);
            }
            
            if (!first || !second) {
                $$ = NULL;
            } else if($2 == '+') {
                emit("RADD",res->name,first->name,second->name);
            } else if($2 == '-'){
                emit("RSUB",res->name,first->name,second->name);
            }
        } else { 
            if($2 == '+') {
                emit("IADD",res->name,$1->name,$3->name);
            } else if($2 == '-'){
                emit("ISUB",res->name,$1->name,$3->name);
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
            Symbol *first = $1;
            Symbol *second = $3;

            if($1->type == TYPE_INT){
                first = convertToFloat($1);
                emit("ITOR", first->name, $1->name, NULL);
            }

            if($3->type == TYPE_INT){
                second = convertToFloat($3);
                emit("ITOR", second->name, $3->name, NULL);
            }

            if (!first || !second) {
                $$ = NULL;
            } else if($2 == '*') {
                emit("RMLT",res->name,first->name,second->name);
            } else if($2 == '/'){
                emit("RDIV",res->name,first->name,second->name);
            }
        } else { 
            if($2 == '*') {
                emit("IMLT",res->name,$1->name,$3->name);
            } else if($2 == '/'){
                emit("IDIV",res->name,$1->name,$3->name);
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

            emit("RTOI",res->name,$3->name,NULL);
        }
        else { /* Cast to FLOAT */
            res = createTemp(TYPE_FLOAT,$3->value);

            emit("ITOR",res->name,$3->name,NULL);
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
    $$ = num; 
}

M: /* empty */ {
    $$=next_instr;
}

N: /* empty */ {
    $$ = makeList(next_instr); 
    emit("JMP","_",NULL,NULL);
}

%%
Instruction code[MAX_INSTR];
int next_instr;

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

// Adding instructions to the instructions list 
void emit(const char *op,const char *arg1,const char *arg2,const char *arg3){
    code[next_instr].op = strdup(op);

    code[next_instr].arg1 = arg1 ? strdup(arg1) : NULL;
    code[next_instr].arg2 = arg2 ? strdup(arg2) : NULL;
    code[next_instr].arg3 = arg3 ? strdup(arg3) : NULL;

    next_instr++;
}

jmpList *makeList(int instr){
    jmpList *node = malloc(sizeof(jmpList));
    node->ptr = instr;
    node->next = NULL;

    return node;
}

jmpList *merge(jmpList *first, jmpList *second){
    if (!first) return second;
    if (!second) return first;

    jmpList* temp = first;
    while (temp->next)
        temp = temp->next;

    temp->next = second;
    return first;
}

void patch_instruction(int instr_ptr, int target) {
    char buf[16];
    sprintf(buf, "%d", target);

    free(code[instr_ptr].arg1);
    code[instr_ptr].arg1 = strdup(buf);
}

void backpatch(jmpList *lst, int target) {
    while(lst) {
        patch_instruction(lst->ptr,target);
        lst = lst->next;
    }
}

void printCode() {
    for(int i = 0; i < next_instr; i++)
    {
        printf("%d: %s", i, code[i].op);

        if(code[i].arg1) printf(" %s", code[i].arg1);
        if(code[i].arg2) printf(" %s", code[i].arg2);
        if(code[i].arg3) printf(" %s", code[i].arg3);

        printf("\n");
    }
}

void freeCode() {
    for(int i = 0; i < next_instr; i++)
    {
        if(code[i].arg1) free(code[i].arg1);
        if(code[i].arg2) free(code[i].arg2);
        if(code[i].arg3) free(code[i].arg3);
    }
}