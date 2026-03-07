#include <stdio.h>
#include <stdlib.h>
#include <string.h>


#include "symbol_table.h"

Symbol* symbolTable[TABLE_SIZE];

int tempCount = 0;

// Hash function
uint32_t hash(const char *s) {
    uint32_t h = 5381;
    unsigned char c;

    while ((c = (unsigned char)*s++)) {
        h = ((h << 5) + h) + c;
    }

    return h % (uint32_t)TABLE_SIZE;
}

void initSymbolTable(void){
    for(int i=0;i<TABLE_SIZE;i++){
        symbolTable[i] = NULL;
    }
}

Symbol *insertSymbol(SymbolType type, char* name, SymbolValue value){
    Symbol *newSymbol = malloc(sizeof(Symbol));

    newSymbol->name = strdup(name); // Copy name into the newly created Symbol

    newSymbol->type=type; // Assign type

    newSymbol->value = value;

    size_t hashed = hash(name);

    newSymbol->next = symbolTable[hashed];
    symbolTable[hashed] = newSymbol;

    return newSymbol;
}

Symbol *insertInt(char* name, int value){
    SymbolValue val;
    val.i = value;
    return insertSymbol(TYPE_INT,name,val);
}

Symbol *insertFloat(char* name, float value) {
    SymbolValue val;
    val.f = value;
    return insertSymbol(TYPE_FLOAT,name,val);
}

Symbol *insertPtr(char* name, void* value) {
    SymbolValue val;
    val.ptr = value;
    return insertSymbol(TYPE_ID,name,val);
}

Symbol *lookup(char* name) {
    size_t hashed = hash(name);

    Symbol *temp = symbolTable[hashed];

    while(temp){
        if(!strcmp(name,temp->name)){
            return temp;
        }

        temp = temp->next;
    }
    
    return NULL;
}

void removeSymbol (char* name){
    size_t hashed = hash(name);

    Symbol *temp = symbolTable[hashed]; 
    if(temp && !strcmp(temp->name,name)){
        symbolTable[hashed] = symbolTable[hashed]->next;
        free(temp->name);
        free(temp);
    } else {
        while(temp && temp->next) {
            if(!strcmp(temp->next->name,name)){
                Symbol *toRelease = temp->next;
                temp->next = temp->next->next;
                free(toRelease->name);
                free(toRelease);
                return;
            }

            temp = temp->next;
        }
    }
}

void cleanSymbolTable(void) {
    for(int i=0; i<TABLE_SIZE;i++){
        Symbol *temp = symbolTable[i];

        while(temp){
            Symbol *next = temp->next;
            free(temp->name);
            free(temp);
            temp = next;
        }
    }
}

char *newTemp(){
    char buffer[32];

    snprintf(buffer, sizeof(buffer), "_t%d", tempCount++);

    return strdup(buffer);
}

Symbol *createTemp(SymbolType type, SymbolValue value){
    Symbol *temp = malloc(sizeof(Symbol));

    temp->name = newTemp();
    temp->type = type;
    temp->value = value;
    temp->next = NULL;

    return temp;
}

// void printSymbol(Symbol *sym){
//     if(sym->type == TYPE_INT) printf("int %d\n",sym->value.i);
//     else if(sym->type == TYPE_FLOAT) printf("float %f\n",sym->value.f);
//     else printf("ptr %s\n",sym->value.ptr);
// }

// void printSymbolTable(){
//     for(int i=0;i<TABLE_SIZE;i++){
//         if(symbolTable[i]){
//             Symbol *temp = symbolTable[i];
//             while(temp){
//                 printf("symbol: ");
//                 printSymbol(temp);
//                 temp=temp->next;
//             }
//         }
//     }
// }