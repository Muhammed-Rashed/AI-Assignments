:- consult('ai6.pl').
:- consult('Print.pl').

% -------------------------
% Choose sides
% -------------------------
human_player(d).   % human plays defenders
ai_player(a).      % AI plays attackers

% -------------------------
% Start the match
% -------------------------
start_game :-
    initial_board(Board),
    play(Board, a, 5, 300).   % AI starts (attacker)

% -------------------------
% Game loop
% -------------------------
play(_, _, _, 0) :-
    write('Move limit reached.'), nl, !.

play(Board, Player, Depth, Limit) :-
    print_board(Board), nl,
    write('Player: '), write(Player), nl, nl,
    NewLimit is Limit - 1,
    ( game_over(Board, Winner) ->
        write('GAME OVER! Winner: '), write(Winner), nl
    ;
        ( human_player(Player) ->
            human_move(Board, Player, NewBoard)
        ;
            best_move(Board, Player, Depth, NewBoard)
        ),
        switch(Player, NextPlayer),
        play(NewBoard, NextPlayer, Depth, NewLimit)
    ).

% -------------------------
% Human move
% -------------------------
human_move(Board, Player, NewBoard) :-
    repeat,
    write('Enter move as: R1. C1. R2. C2. (with dots, 0-10): '), nl,
    read(R1), read(C1), read(R2), read(C2),
    ( move(Board, R1, C1, R2, C2, _, NewBoard) ->
        true
    ;
        write('Invalid move, try again.'), nl, fail
    ), !.

% -------------------------
% AI move (Alpha-Beta)
% -------------------------
best_move(Board, Player, Depth, BestBoard) :-
    (Player = a -> IsMax = true ; IsMax = false),
    alphabeta(Board, -999999, 999999, BestBoard, Depth, Player, 5, _).

% -------------------------
% Switch players
% -------------------------
switch(a, d).
switch(d, a).

% -------------------------
% Game over conditions
% -------------------------
game_over(Board, a) :-
    king_captured(Board).

game_over(Board, d) :-
    king_escaped(Board).

% -------------------------
% Initial state
% -------------------------
initial_board(Board) :-
    board(Board).