% --- Imports ---
:- consult('Board.pl').

% --- Helpers ---
in_bounds((R, C), Grid) :-
    length(Grid, MaxR),
    nth0(0, Grid, FirstRow),
    length(FirstRow, MaxC),
    R >= 0, R < MaxR,
    C >= 0, C < MaxC.

% check if no piece exists
empty_cell(R, C, Board) :-
    get_piece(Board, R, C, e).

occupied(R, C, Board) :-
    \+ empty_cell(R, C, Board).

% piece types
enemy(a, d).
enemy(d, a).

% Switch from attacker to defender and vice versa
switch(a, d).
switch(d, a).

adjacent(R, C, R, C2) :- C2 is C+1.
adjacent(R, C, R, C2) :- C2 is C-1.
adjacent(R, C, R2, C) :- R2 is R+1.
adjacent(R, C, R2, C) :- R2 is R-1.

opposite(R, C, R2, C2, R3, C3) :-
    R3 is 2*R2 - R,
    C3 is 2*C2 - C.


% --- Path validation ---
% Ensure the path is clear so no piece go through the other
path_clear(R1, C1, R2, C2, Board) :-
    (R1 =:= R2 -> clear_horizontal(R1, C1, C2, Board);C1 =:= C2 -> clear_vertical(C1, R1, R2, Board)).

% Check horizontal path
clear_horizontal(R, C1, C2, Board) :-
    Step is sign(C2 - C1),
    CStart is C1 + Step,
    clear_h_loop(R, CStart, C2, Step, Board).

% loop over the path
clear_h_loop(_, C, C, _, _).
clear_h_loop(R, C, C2, Step, Board) :-
    empty_cell(R, C, Board),
    CNext is C + Step,
    clear_h_loop(R, CNext, C2, Step, Board).

% Check vertical path
clear_vertical(C, R1, R2, Board) :-
    Step is sign(R2 - R1),
    RStart is R1 + Step,
    clear_v_loop(C, RStart, R2, Step, Board).

clear_v_loop(_, R, R, _, _).
clear_v_loop(C, R, R2, Step, Board) :-
    empty_cell(R, C, Board),
    RNext is R + Step,
    clear_v_loop(C, RNext, R2, Step, Board).

% check if the position is not safe to go to
unsafe_position(Board, Type, R, C) :-
    enemy(Type, Enemy),
    adjacent(R, C, R2, C2),
    get_piece(Board, R2, C2, Enemy),

    opposite(R2, C2, R, C, R3, C3),
    (
        get_piece(Board, R3, C3, Enemy)
        ;
        (special_cell(R3, C3), empty_cell(R3, C3, Board))
    ).


% --- Update Board ---
set_cell(Board, R, C, Val, NewBoard) :-
    nth0(R, Board, Row),
    replace(Row, C, Val, NewRow),
    replace(Board, R, NewRow, NewBoard).

replace([_|T], 0, X, [X|T]).
replace([H|T], I, X, [H|R]) :-
    I > 0,
    I1 is I - 1,
    replace(T, I1, X, R).

is_turn_piece(a, a).
is_turn_piece(d, d).
is_turn_piece(k, d).   % king belongs to defender turn

valid_move(Board, R1, C1, R2, C2, Type, Turn) :-
    get_piece(Board, R1, C1, Type),

    is_turn_piece(Type, Turn),

    empty_cell(R2, C2, Board),
    (R1 =:= R2 ; C1 =:= C2),
    path_clear(R1, C1, R2, C2, Board),

    (special_cell(R2, C2) -> Type = k ; true),

    \+ unsafe_position(Board, Type, R2, C2).
% --- Move ---
move(Board, R1, C1, R2, C2, Type, FinalBoard) :-
    % correct piece at source
    get_piece(Board, R1, C1, Type),

    % destination empty
    empty_cell(R2, C2, Board),

    % straight line
    (R1 =:= R2 ; C1 =:= C2),

    % path clear
    path_clear(R1, C1, R2, C2, Board),

    % only king enters special
    (special_cell(R2, C2) -> Type = k ; true),

    % check if move safe
    \+ unsafe_position(Board, Type, R2, C2),

    % move
    set_cell(Board, R1, C1, e, TempBoard),
    set_cell(TempBoard, R2, C2, Type, MovedBoard),

    % apply captures
    capture_all(MovedBoard, R2, C2, Type, FinalBoard).

% --- Capture rules ---
capture_all(Board, R, C, Type, FinalBoard) :-
    findall((R2,C2),
        capturable(Board, R, C, Type, R2, C2),ToRemove),
    
    remove_pieces(Board, ToRemove, FinalBoard).

capturable(Board, R, C, Type, R2, C2) :-
    adjacent(R, C, R2, C2),
    get_piece(Board, R2, C2, EnemyType),
    enemy(Type, EnemyType),

    opposite(R, C, R2, C2, R3, C3),
    (
        get_piece(Board, R3, C3, Type)
        ;
        (special_cell(R3, C3), empty_cell(R3, C3, Board))
    ).

remove_pieces(Board, [], Board).
remove_pieces(Board, [(R,C)|T], FinalBoard) :-
    set_cell(Board, R, C, e, Temp),
    remove_pieces(Temp, T, FinalBoard).


% King Capture
king_captured(Board) :-
    get_piece(Board, R, C, k),
    surrounded(Board, R, C).

% King Escape
king_escaped(Board) :-
    get_piece(Board, R, C, k),
    corner(R, C).

% Check if king is surrounded
surrounded(Board, R, C) :-
    findall((R2,C2), adjacent(R,C,R2,C2), Adj),
    count_blocked(Board, Adj, Count),
    required_sides(R, C, Req),
    Count >= Req.

% Count blocking sides
count_blocked(_, [], 0).
count_blocked(Board, [(R,C)|T], Count) :-
    get_piece(Board, R, C, a),
    count_blocked(Board, T, C1),
    Count is C1 + 1.

count_blocked(Board, [_|T], Count) :-
    count_blocked(Board, T, Count).


% Required sides depending on position
required_sides(R, C, 4) :- \+ edge(R,C), \+ corner(R,C).
required_sides(R, C, 3) :- edge(R,C), \+ corner(R,C).
required_sides(R, C, 2) :- corner(R,C).


% --- Human turns ---
playTurn(state(Board,Type), R1,C1, R2,C2, NewBoard, AttackersWon, DefendersWon) :-
    move(Board, R1, C1, R2, C2, Type, NewBoard),

    % Check if defenders won
    ( king_escaped(NewBoard) -> DefendersWon = true ; DefendersWon = false ),
    
    % Check if attackers won
    ( king_captured(NewBoard) -> AttackersWon = true ; AttackersWon = false ).
