compile:
	bison -d cpq.y
	flex cpq.l
	gcc -o cpq lex.yy.c cpq.tab.c -lfl