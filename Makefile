compile:
	bison -d cpq.y
	flex cpq.l
	gcc cpq.tab.c lex.yy.c symbol_table.c -I. -lfl -o cla