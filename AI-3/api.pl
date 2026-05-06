:- consult('Board.pl').
:- consult('move.pl').
:- consult('ai7.pl').

evaluate_game_state(Board, defenders_win) :-
    king_escaped(Board), !.

evaluate_game_state(Board, attackers_win) :-
    king_captured(Board), !.

evaluate_game_state(_, ongoing).

% VALID MOVES
valid_moves(Board, R, C, Turn, Moves) :-
    get_piece(Board, R, C, Type),
    is_turn_piece(Type, Turn),
    findall([R2, C2],
        valid_move(Board, R, C, R2, C2, Type, Turn),
        Moves
    ).

% APPLY MOVE (NO STATE INSIDE PROLOG)
apply_move(Board, R1, C1, R2, C2, Turn, NewBoard, GameState) :-
    get_piece(Board, R1, C1, Type),
    is_turn_piece(Type, Turn),

    move(Board, R1, C1, R2, C2, Type, TempBoard),

    evaluate_game_state(TempBoard, GameState),
    NewBoard = TempBoard.

    % AI MOVE WRAPPER
ai_move(Board, Turn, Depth, Width, NewBoard, GameState) :-
    % Alpha and Beta initial values
    Alpha is -1000000,
    Beta is 1000000,

    % Call your AI
    alphabeta(Board, Alpha, Beta, BestBoard, Depth, Turn, Width, _),

    % Return result
    NewBoard = BestBoard,

    % Evaluate game state after AI move
    evaluate_game_state(NewBoard, GameState).