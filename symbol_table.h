#include <stdint.h>

#ifndef SYMBOL_TABLE_H
#define SYMBOL_TABLE_H

#define TABLE_SIZE 211

typedef enum {
        TYPE_INT,
        TYPE_FLOAT,
        TYPE_STRING,
        TYPE_ID
    } SymbolType;

typedef union {
    int i;
    float f;
    void *ptr;
} SymbolValue;

typedef struct Symbol {
    SymbolType type; 
    char* name;
    SymbolValue value;
    // TODO: add line number?
    int is_literal; // 1 - if created from NUM, else - 0
    struct Symbol* next;
} Symbol;

typedef struct IRSymNode {
    Symbol *sym;
    struct IRSymNode *next;
} IRSymNode;

void initSymbolTable(void);
Symbol *insertSymbol(SymbolType type, char* name, SymbolValue value);
Symbol *insertInt(char* name, int value);
Symbol *insertFloat(char* name, float value);
Symbol *lookup(char* name);
void removeSymbol (char* name);
void cleanSymbolTable(void);
char *newTemp();
Symbol *createTemp(SymbolType type, SymbolValue value);
Symbol *convertToFloat(Symbol *x);
void freeTemporaries();
void addIRSym(Symbol *sym);

#endif