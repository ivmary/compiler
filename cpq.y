%code {
    // Mary Ivshenko 212051189 
    // Miriam Mizrahi 312599293

    // Forward declarations for lexer, parser, and helper functions
    extern int yylex();
    extern int yyparse();

    void yyerror (const char *s, ...);
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
    #include <stdio.h>
    #include <string.h>
    #include <stdarg.h>
    #include "symbol_table.h"
    #define MAX_INSTR 1000
    #define INSTR_LEN 64
    
    // Data structure to hold numeric literal values with their type information
    typedef struct NumData {
        SymbolType type;
        union {
            int ival;
            float fval;
        } value;
    } NumData;

    // Linked list structure for holding multiple identifiers during declaration
    typedef struct idNamesList {
        char* name;
        struct idNamesList *next;
    } idNamesList;

    // Enumeration for all relational operators
    typedef enum {
        RELOP_EQ, // == 
        RELOP_NE, // !=
        RELOP_LT, // <
        RELOP_GT, // >
        RELOP_LE, // <=
        RELOP_GE // >=
    } RelOp;

    // Linked list of instruction addresses that need backpatching
    typedef struct jmpList{
        int ptr;
        struct jmpList *next;
    } jmpList;

    // Attributes for boolean expressions: lists of instructions that jump on true/false
    typedef struct {
        jmpList* truelist;
        jmpList* falselist;
    } BoolAttr;

    // Attributes for statements: list of break instructions that need backpatching
    typedef struct {
        jmpList* breaklist;
    } StmtAttr;

    // Attributes for switch cases: the expression being switched, break list, and fallthrough list
    typedef struct {
        Symbol* expr;
        jmpList* breaklist;
        jmpList* nextlist;
    } CaseAttr;

    // Single three-address code instruction
    typedef struct Instruction{
        const char* op;     // instruction opcode 
        char* arg1;         // first argument (usually destination or jump target)
        char* arg2;         // second argument (first operand)
        char* arg3;         // third argument (second operand)
    }Instruction;

    extern Instruction code[MAX_INSTR];
    extern int next_instr;

    extern FILE *yyin;
    extern FILE *yyout;

    extern int compile_success;
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

program: declarations stmt_block { }

declarations : declarations declaration { } 
| /* epsilon */ {}

declaration : idlist ':' type ';' {
    // Process each identifier in the declaration list
    idNamesList *tempId = $1;

    // Insert all declared variables into the symbol table with default values
    while(tempId){
        if($3 == TYPE_INT) {
            Symbol * temp=insertInt(tempId->name,314);
            }
        else if($3 == TYPE_FLOAT) {
            Symbol * temp=insertFloat(tempId->name, 3.14);
            }
        tempId = tempId-> next;
    }

    // Free the temporary linked list of identifier names
    tempId = $1;
    while(tempId){
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

    if (!id) {
        yyerror("variable '%s' has not been declared", $1);
    }
    else if (!$3) {
        yyerror("expression in assignment to '%s' is invalid", $1);
    }
    else if (id->type == $3->type) {
        if (id->type == TYPE_INT) {
            emit("IASN", id->name, $3->name, NULL);
        } else if (id->type == TYPE_FLOAT) {
            emit("RASN", id->name, $3->name, NULL);
        } else {
            yyerror("unsupported type in assignment to '%s'", $1);
        }
    }
    else if (id->type == TYPE_FLOAT && $3->type == TYPE_INT) {
        Symbol *temp = convertToFloat($3);
        emit("ITOR", temp->name, $3->name, NULL);
        emit("RASN", id->name, temp->name, NULL);
    }
    else {
        yyerror("type mismatch in assignment to '%s'. Expected %s, got %s", $1, (id->type == TYPE_INT) ? "int" : "float", ($3->type == TYPE_INT) ? "int" : "float");
    }
}

input_stmt : INPUT '(' ID ')' ';' {
    Symbol *id = lookup($3);
    if(id) {
        if(id->type == TYPE_INT) {
            emit("IINP",id->name,NULL,NULL);
        } else if(id->type == TYPE_FLOAT){
            emit("RINP",id->name,NULL,NULL);
        } else {
            yyerror("unsupported type for input to '%s'", $3);
        }
    }
    else {
        yyerror("input variable '%s' has not been declared", $3);
    }
}

output_stmt : OUTPUT '(' expression ')' ';' {
    if($3){
        if($3->type == TYPE_INT) {
            emit("IPRT",$3->name,NULL,NULL);
        } else if($3->type == TYPE_FLOAT){
            emit("RPRT",$3->name,NULL,NULL);
        } else {
            yyerror("unsupported type in output expression");
        }
    } else {
        yyerror("output expression is invalid or uses undeclared variable");
    }
}

if_stmt : IF '(' boolexpr ')' M {
    // Backpatch true branches of condition to jump to if body (M marker)
    backpatch($3->truelist,$5);
}
stmt N ELSE M {
    // Save jump around else clause (N), then backpatch false branches to else body
    backpatch($3->falselist,$10);
}
stmt {
    // Backpatch jumps from if body to instruction after if-else
    backpatch($8,next_instr);
    $$ = malloc(sizeof(StmtAttr));
    // Merge break lists from both branches
    $$->breaklist = merge($7->breaklist,$12->breaklist);
}

while_stmt : WHILE '(' M boolexpr ')' M stmt {
    // Emit jump back to loop test (M = start of while condition)
    char buff[16];
    snprintf(buff,sizeof(buff),"%d",$3);
    emit("JUMP",buff,NULL,NULL);

    // Backpatch true branches to jump to loop body (second M marker)
    backpatch($4->truelist, $6);
    // Backpatch false branches to jump past loop (next_instr)
    backpatch($4->falselist,next_instr);
    // Backpatch break statements to jump past loop
    backpatch($7->breaklist,next_instr);
    $$ = malloc(sizeof(StmtAttr));
    $$->breaklist = NULL;
}

switch_stmt : SWITCH '(' expression ')' S '{' caselist M DEFAULT ':' stmtlist '}' {
    // Verify that switch expression is integer type (required by language)
    if($3->type!=TYPE_INT) yyerror("switch expression must be of type int, got %s", ($3->type == TYPE_FLOAT) ? "float" : "unknown");
    // Backpatch all break statements from cases to instruction after switch
    backpatch($7->breaklist,next_instr);
    // Backpatch fallthrough from cases to default clause
    backpatch($7->nextlist, $8);
    // Backpatch break statements from default clause
    backpatch($11->breaklist,next_instr);

    $$ = malloc(sizeof(StmtAttr));
    $$->breaklist = NULL;
}

S: /* empty */ {
    $$ = $<sym>-2;
}

caselist : caselist CASE NUM ':' {
    // Backpatch previous case's fallthrough to this case's condition check
    backpatch($1->nextlist, next_instr);
    if($3.type != TYPE_INT) yyerror("case constant must be of type int, got %s", ($3.type == TYPE_FLOAT) ? "float" : "unknown");
    
    // Compare switch expression with case constant and jump if not equal
    char buff[16];
    snprintf(buff,sizeof(buff),"%d",$3.value.ival);

    Symbol *temp = createTemp(TYPE_INT,(SymbolValue){0});
    emit("IEQL",temp->name,$1->expr->name,buff);

    // Save instruction address of conditional jump for later patching
    $<ival>$ = next_instr;
    emit("JMPZ","_",temp->name,NULL);

}  stmtlist {
    $$ = malloc(sizeof(CaseAttr));
    $$->expr = $1->expr;    
    // Merge break lists from previous cases and current case's statements
    $$->breaklist = merge($1->breaklist,$6->breaklist);
    // Create fallthrough list for jumping to next case if this one doesn't match
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
    // NOT operator: swap the true and false jump lists
    $$ = $3;

    jmpList* tmp = $$->truelist;
    $$->truelist = $$->falselist;
    $$->falselist = tmp;
}
| expression RELOP expression {
    // Boolean comparison: handle type conversion and generate comparison code
    if(!$1 || !$3) { $$=NULL; }
    else if(!($1->type == TYPE_INT || $1->type == TYPE_FLOAT) || 
        !($3->type == TYPE_INT || $3->type == TYPE_FLOAT)) { $$=NULL; }
    else {
        // Determine if floating point operations needed
        int useFloat = ($1->type == TYPE_FLOAT || $3->type == TYPE_FLOAT);

        Symbol *first = $1;
        Symbol *second = $3;

        // Convert operands to float if needed for mixed type comparison
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

            // Generate opcode (IEQL, INQL, etc. for int; REQL, RNQL, etc. for float)
            char opcode[10];
            sprintf(opcode, "%c%s", useFloat ? 'R' : 'I', relop_to_opcode($2));

            // Perform comparison and store result in temp variable
            Symbol *temp = createTemp(TYPE_INT,(SymbolValue){0});
            emit(opcode,
                temp->name,
                first->name,
                second->name);
            
            // Generate conditional jump (false branch)
            jmpList *t1 = makeList(next_instr);
            emit("JMPZ","_",temp->name,NULL);

            // Generate unconditional jump (true branch)
            jmpList *t2 = makeList(next_instr);
            emit("JUMP","_",NULL,NULL);

            // Assign true/false lists based on operator type
            if ($2 == RELOP_LE || $2 == RELOP_GE) 
            {
                $$->falselist = t2;
                $$->truelist = t1;
            }
            else {
                $$->falselist = t1;
                $$->truelist = t2;
            }
        }
        
    }
}

expression : expression ADDOP term { 
    // Addition/subtraction: handle type conversion and emit appropriate opcode
    if (!$1 || !$3) {
        yyerror("invalid operand in arithmetic expression (missing or undeclared variable)");
        $$ = NULL;
    }
    else if (($1->type == TYPE_INT || $1->type == TYPE_FLOAT) && 
        ($3->type == TYPE_INT || $3->type == TYPE_FLOAT)) {

        // Result type is float if either operand is float, otherwise int
        SymbolType resType = ($1->type == TYPE_FLOAT || $3->type == TYPE_FLOAT) ? TYPE_FLOAT : TYPE_INT;
        SymbolValue dummy = (SymbolValue){0};
        Symbol *res = createTemp(resType, dummy);

        if (resType == TYPE_FLOAT) {
            // Float operation: convert int operands to float if needed
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
            // Integer operation
            if($2 == '+') {
                emit("IADD",res->name,$1->name,$3->name);
            } else if($2 == '-'){
                emit("ISUB",res->name,$1->name,$3->name);
            }    
        }
        $$ = res;
    } else {
        yyerror("type mismatch in %s operation. Both operands must be numeric (int or float)", ($2 == '+') ? "addition" : "subtraction");
        $$ = NULL;
    }
    }
| term {
    $$ = $1;
}

term : term MULOP factor { 
    // Multiplication/division: handle type conversion and emit appropriate opcode
    if (!$1 || !$3) {
        yyerror("invalid operand in arithmetic expression (missing or undeclared variable)");
        $$ = NULL;
    }
    else if (($1->type == TYPE_INT || $1->type == TYPE_FLOAT) && 
        ($3->type == TYPE_INT || $3->type == TYPE_FLOAT)) {

        // Result type is float if either operand is float, otherwise int
        SymbolType resType = ($1->type == TYPE_FLOAT || $3->type == TYPE_FLOAT) ? TYPE_FLOAT : TYPE_INT;
        SymbolValue dummy = (SymbolValue){0};
        Symbol *res = createTemp(resType, dummy);

        if (resType == TYPE_FLOAT) {
            // Float operation: convert int operands to float if needed
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
            // Integer operation
            if($2 == '*') {
                emit("IMLT",res->name,$1->name,$3->name);
            } else if($2 == '/'){
                emit("IDIV",res->name,$1->name,$3->name);
            }    
        }
        $$ = res;
    } else {
        yyerror("type mismatch in %s operation. Both operands must be numeric (int or float)", ($2 == '*') ? "multiplication" : "division");
        $$ = NULL;
    }
    }
| factor {
    $$ = $1;
}

factor : '(' expression ')' {
    // Parenthesized expression
    $$ = $2;}
| CAST '(' expression ')' {
    // Type casting: convert expression to specified type
    if ($3->type != TYPE_INT && $3->type != TYPE_FLOAT) {
        yyerror("cannot cast invalid or undeclared expression");
        $$ = NULL;
    }
    else{
        Symbol *res = NULL;

        if ($1 == TYPE_INT) {
            // Cast to INT: convert float to int
            res = createTemp(TYPE_INT,$3->value);
            emit("RTOI",res->name,$3->name,NULL);
        }
        else {
            // Cast to FLOAT: convert int to float
            res = createTemp(TYPE_FLOAT,$3->value);
            emit("ITOR",res->name,$3->name,NULL);
        }

        $$ = res;
    }}
| ID {
    // Variable reference: look up in symbol table
    Symbol *id = lookup($1);
    if(id) {
        $$ = id;
    }
    else {
        yyerror("undeclared identifier '%s'", $1);
        $$ = NULL;
    }

    free($1); }
| NUM {
    // Numeric literal: create a symbol for the constant
    Symbol *num = malloc(sizeof(Symbol));

    num->type = $1.type;
    num->next = NULL;

    if (num->type == TYPE_INT) {
        num->value.i = $1.value.ival;
        // Convert integer value to string for symbol name
        char buf[32];
        snprintf(buf, sizeof(buf), "%d", num->value.i);
        num->name = strdup(buf);
    } else {
        // Float literal: convert to string representation
        num->value.f = $1.value.fval;
        char buf[64];
        snprintf(buf, sizeof(buf), "%g", num->value.f);
        num->name = strdup(buf);
    }
    
    // Add to code generation symbol table
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
// Global code array and instruction counter for three-address code generation
Instruction code[MAX_INSTR];
int next_instr;
int compile_success = 1;

int main(int argc, char **argv){
    // Initialize symbol table
    initSymbolTable();

    // Validate command line arguments
    if (argc != 2) {
        fprintf (stderr, "Usage: %s <input-file-name>\n", argv[0]);
	    return 1;
    }

    // Verify input file has .ou extension
    char *input = argv[1];
    int len = strlen(input);

    if (len < 3 || strcmp(input + len - 3, ".ou") != 0) {
        fprintf(stderr, "Error: input file must end with .ou\n");
        return 1;
    }

    // Open input file for lexing and parsing
    yyin = fopen (argv [1], "r");
    if (yyin == NULL) {
        fprintf (stderr, "Error: failed to open %s\n", argv[1]);
        return 2;
    }
    
    // Run the parser to generate three-address code
    yyparse ();
    fclose (yyin);

    // Create output file only if compilation was successful
    if(compile_success)
    {
        // Create output filename by replacing .ou with .qud
        char output[256];
        strncpy(output, input, len - 3);
        output[len - 3] = '\0';
        strcat(output, ".qud");

        // Open output file for writing generated code
        yyout = fopen(output, "w");
        if (!yyout) {
            fprintf(stderr, "Error: failed to create %s\n", output);
            return 3;
        }

        // Write generated three-address code to output file
        printCode();
        fprintf(yyout, "HALT\n"); // End of program
        
        // Clean up: close files and free allocated memory
        fclose(yyout);
    }   

    freeCode();
    cleanSymbolTable();
    freeTemporaries();

    return compile_success ? 0 : 1;
}


void yyerror (const char *s, ...)
{
    extern int yylineno;
    va_list args;
    va_start(args, s);
    fprintf(stderr, "%d: Error: ", yylineno);
    vfprintf(stderr, s, args);
    fprintf(stderr, "\n");
    va_end(args);

    compile_success = 0;
}

// Convert relational operator enum to corresponding three-address code opcode
static const char *relop_to_opcode(RelOp op) {
    switch (op) {
        case RELOP_EQ: return "EQL";  // Equal
        case RELOP_NE: return "NQL";  // Not equal
        case RELOP_LT: return "LSS";  // Less than
        case RELOP_GT: return "GRT";  // Greater than
        case RELOP_LE: return "GRT";  // Less than or equal
        case RELOP_GE: return "LSS";  // Greater than or equal
        default:       return NULL;
    }
}

// Emit a three-address code instruction to the instruction array
void emit(const char *op,const char *arg1,const char *arg2,const char *arg3){
    // Allocate and store instruction opcode
    code[next_instr].op = strdup(op);

    // Store up to three arguments (destination and operands)
    code[next_instr].arg1 = arg1 ? strdup(arg1) : NULL;
    code[next_instr].arg2 = arg2 ? strdup(arg2) : NULL;
    code[next_instr].arg3 = arg3 ? strdup(arg3) : NULL;

    // Advance to next instruction slot
    next_instr++;
}

// Create a new jump list with a single instruction address
jmpList *makeList(int instr){
    jmpList *node = malloc(sizeof(jmpList));
    node->ptr = instr;
    node->next = NULL;

    return node;
}

// Merge two jump lists into one (concatenate)
jmpList *merge(jmpList *first, jmpList *second){
    if (!first) return second;
    if (!second) return first;

    // Find the last node in the first list
    jmpList* temp = first;
    while (temp->next)
        temp = temp->next;

    // Append second list to first list
    temp->next = second;
    return first;
}

// Update a jump instruction to target a specific address
void patch_instruction(int instr_ptr, int target) {
    char buf[16];
    sprintf(buf, "%d", target);

    // Replace placeholder jump target with actual address
    free(code[instr_ptr].arg1);
    code[instr_ptr].arg1 = strdup(buf);
}

// Backpatch all instructions in a list with a target address
void backpatch(jmpList *lst, int target) {
    // Update each jump instruction's target in the list
    while(lst) {
        patch_instruction(lst->ptr,target);
        lst = lst->next;
    }
}

// Write all generated three-address code instructions to output file
void printCode() {
    for(int i = 0; i < next_instr; i++)
    {
        // Format: instruction_number: opcode arg1 arg2 arg3
        fprintf(yyout,"%s", code[i].op);

        // Print arguments if they exist
        if(code[i].arg1) fprintf(yyout," %s", code[i].arg1);
        if(code[i].arg2) fprintf(yyout," %s", code[i].arg2);
        if(code[i].arg3) fprintf(yyout," %s", code[i].arg3);

        fprintf(yyout,"\n");
    }
}

// Free all allocated strings in instructions array
void freeCode() {
    for(int i = 0; i < next_instr; i++)
    {
        if(code[i].arg1) free(code[i].arg1);
        if(code[i].arg2) free(code[i].arg2);
        if(code[i].arg3) free(code[i].arg3);
    }
}