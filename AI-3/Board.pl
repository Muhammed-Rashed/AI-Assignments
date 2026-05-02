% 11x11 Board
board([
    % King
    piece(king, 6, 6),
    
    % Defenders
    piece(defender, 6, 4), piece(defender, 6, 5), piece(defender, 6, 7), piece(defender, 6, 8),
    piece(defender, 4, 6), piece(defender, 5, 6), piece(defender, 7, 6), piece(defender, 8, 6),
    piece(defender, 5, 5), piece(defender, 5, 7), piece(defender, 7, 5), piece(defender, 7, 7),

    % Attackers
    % Top
    piece(attacker, 1, 4), piece(attacker, 1, 5), piece(attacker, 1, 6), 
    piece(attacker, 1, 7), piece(attacker, 1, 8), piece(attacker, 2, 6),

    % Bottom
    piece(attacker, 11, 4), piece(attacker, 11, 5), piece(attacker, 11, 6), 
    piece(attacker, 11, 7), piece(attacker, 11, 8), piece(attacker, 10, 6),

    % Left
    piece(attacker, 4, 1), piece(attacker, 5, 1), piece(attacker, 6, 1), 
    piece(attacker, 7, 1), piece(attacker, 8, 1), piece(attacker, 6, 2),

    % Right
    piece(attacker, 4, 11), piece(attacker, 5, 11), piece(attacker, 6, 11), 
    piece(attacker, 7, 11), piece(attacker, 8, 11), piece(attacker, 6, 10)
]).

% State Representaion
initial_state(state(Board, attacker)) :- 
    board(Board).

% Define board borders
edge(1,_).
edge(_,1).
edge(11,_).
edge(_,11).

% Define board corners
corner(1,1).
corner(1,11).
corner(11,1).
corner(11,11).

% Define special cells
special_cell(R,C) :- corner(R,C). % Corners are special
special_cell(6,6). % The thron