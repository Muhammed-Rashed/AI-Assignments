% 11x11 Board
board([ 
    [c, e, e, a, a, a, a, a, e, e, c], 
    [e, e, e, e, e, a, e, e, e, e, e], 
    [e, e, e, e, e, e, e, e, e, e, e], 
    [a, e, e, e, e, d, e, e, e, e, a], 
    [a, e, e, e, d, d, d, e, e, e, a], 
    [a, a, e, d, d, k, d, d, e, a, a], 
    [a, e, e, e, d, d, d, e, e, e, a], 
    [a, e, e, e, e, d, e, e, e, e, a], 
    [e, e, e, e, e, e, e, e, e, e, e], 
    [e, e, e, e, e, a, e, e, e, e, e], 
    [c, e, e, a, a, a, a, a, e, e, c] 
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