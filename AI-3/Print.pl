% Print entire board
print_board(Board) :-
    print_rows(Board, 1).

% Stop after row 11
print_rows(_, 12).
print_rows(Board, R) :-
    nth1(R, Board, Row),
    print_row(Row),
    R1 is R + 1,
    print_rows(Board, R1).

% Print a single row
print_row([]) :- nl.
print_row([Cell | Rest]) :-
    print_cell(Cell),
    write(' '),
    print_row(Rest).

% Print a single cell (replace e with .)
print_cell(e) :- write('.').
print_cell(X) :- write(X).