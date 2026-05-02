% --- Imports ---
:- consult('board.pl').

% --- Helpers ---
% stolen from part2
in_bounds((R, C), Grid) :-
    length(Grid, MaxR),
    nth1(1, Grid, FirstRow),
    length(FirstRow, MaxC),
    R >= 1, R =< MaxR,
    C >= 1, C =< MaxC.

% check if no piece exists
empty_cell(R, C, Board) :-
    \+ member(piece(_, R, C), Board).

occupied(R, C, Board) :-
    member(piece(_, R, C), Board).

% --- Path validation ---
% Ensure the path is clear so no piece go through the other
path_clear(R1, C1, R2, C2, Board) :-
    (R1 =:= R2 -> clear_horizontal(R1, C1, C2, Board)
    ;C1 =:= C2 -> clear_vertical(C1, R1, R2, Board)).

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
    enemy(Enemy, Type),
    capturable(Board, Enemy, R, C, piece(Type, R, C)).

% --- Move ---
move(Board, piece(Type, R1, C1), R2, C2, NewBoard) :-
    % destination must be empty
    empty_cell(R2, C2, Board),

    % must move in straight line
    (R1 =:= R2 ; C1 =:= C2),

    % path must be clear
    path_clear(R1, C1, R2, C2, Board),

    % only king can enter special blocks
    (special_block(R2, C2) -> Type = king ; true),

    % simulate move
    select(piece(Type, R1, C1), Board, TempBoard),
    TempBoard2 = [piece(Type, R2, C2) | TempBoard],

    % cannot move into a capturable position
    \+ unsafe_position(TempBoard2, Type, R2, C2),

    NewBoard = TempBoard2.

% --- Capture rules ---
% Stating some facts
enemy(attacker, defender).
enemy(defender, attacker).
enemy(attacker, king).
enemy(defender, attacker).

% cheeck if a piece is capturable
capturable(Board, Type, R, C, piece(EnemyType, R2, C2)) :-
    enemy(Type, EnemyType),

    adjacent(R, C, R2, C2),
    member(piece(EnemyType, R2, C2), Board),

    opposite(R, C, R2, C2, R3, C3),
    ( member(piece(Type, R3, C3), Board); special_block(R3, C3)).

% Adjacent cells up down left right
adjacent(R, C, R, C2) :- C2 is C+1.
adjacent(R, C, R, C2) :- C2 is C-1.
adjacent(R, C, R2, C) :- R2 is R+1.
adjacent(R, C, R2, C) :- R2 is R-1.

% Compute opposite cell for sandwiching
opposite(R, C, R2, C2, R3, C3) :-
    R3 is 2*R2 - R,
    C3 is 2*C2 - C.

% remove the piece when we capture it
remove_pieces(Board, [], Board).
remove_pieces(Board, [P|Ps], NewBoard) :-
    select(P, Board, Temp),
    remove_pieces(Temp, Ps, NewBoard).


% --- Capturing the king ---
king_captured(Board) :-
    member(piece(king, R, C), Board),
    surrounded(Board, R, C).

% Check if king is surrounded
surrounded(Board, R, C) :-
    findall((R2,C2), adjacent(R,C,R2,C2), Adj),
    count_blocked(Board, Adj, Count),
    required_sides(R, C, Req),
    Count >= Req.

% Count blocking sides
count_blocked(_, [], 0).
count_blocked(Board, [(R,C)|T], Count) :-
    ( member(piece(attacker, R, C), Board); special_block(R, C)),
    count_blocked(Board, T, C1),
    Count is C1 + 1.

count_blocked(Board, [_|T], Count) :-
    count_blocked(Board, T, Count).


% Required sides depending on position
required_sides(R, C, 4) :- \+ edge(R,C), \+ corner(R,C).
required_sides(R, C, 3) :- edge(R,C), \+ corner(R,C).
required_sides(R, C, 2) :- corner(R,C).