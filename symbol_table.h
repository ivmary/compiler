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
    struct Symbol* next;
} Symbol;

void initSymbolTable(void);
void insertSymbol(SymbolType type, char* name, SymbolValue value);
void insertInt(SymbolType type, char* name, int value);
void insertFloat(SymbolType type, char* name, float value);
void insertPtr(SymbolType type, char* name, void* value);
Symbol *lookup(char* name);
void removeSymbol (char* name);
void cleanSymbolTable(void);

// remove
//     void printSymbolTable();
#endif