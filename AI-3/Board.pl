% 9x9 Board
board([
    [e, e, e, a, a, a, e, e, e],
    [e, e, e, e, a, e, e, e, e],
    [e, e, e, e, d, e, e, e, e],
    [a, e, e, e, d, e, e, e, a],
    [a, a, d, d, k, d, d, a, a],
    [a, e, e, e, d, e, e, e, a],
    [e, e, e, e, d, e, e, e, e],
    [e, e, e, e, a, e, e, e, e],
    [e, e, e, a, a, a, e, e, e]  
]).

% State Representaion
initial_state(state(Board, attacker)):- 
    board(Board).

% Define board borders
edge(0,_).
edge(_,0).
edge(8,_).
edge(_,8).

% Define board corners
corner(0,0).
corner(0,8).
corner(8,0).
corner(8,8).

% Define special cells
special_cell(R,C) :- corner(R,C). % Corners are special
special_cell(4,4). % The throne


% Get the piece in a specific position
get_piece(Board, R, C, Piece):-
    nth0(R, Board, Row),
    nth0(C, Row, Piece).