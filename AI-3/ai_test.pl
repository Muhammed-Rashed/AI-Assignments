:- consult('ai.pl').
:- consult('Print.pl').

% -------------------------
% Start the match
% -------------------------
start_game :-
    initial_board(Board),
    play(Board, a, 3, 3).  % depth = 3 (adjust if needed)

% -------------------------
% Game loop
% -------------------------
play(Board, Player, Depth, Limit) :-
    print_board(Board),
    nl,
    write('Player: '), write(Player), nl, nl,

    NewLimit is Limit - 1,

    ( game_over(Board, Winner) ->
        write('GAME OVER! Winner: '), write(Winner), nl
    ;
        best_move(Board, Player, Depth, NewBoard),
        switch(Player, NextPlayer),
        play(NewBoard, NextPlayer, Depth, NewLimit)
    ).
play(_,_,_,0) :- fail, !.

% -------------------------
% Get best move using Alpha-Beta
% -------------------------
best_move(Board, Player, Depth, BestBoard) :-
    alphabeta(Board,
              -999999, 999999,
              BestBoard,
              Depth,
              Player,
              true,
              _).


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
% Initial state wrapper
% -------------------------
initial_board(Board) :-
    board(Board).